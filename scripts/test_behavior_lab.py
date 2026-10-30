import json
import tempfile
import unittest
from pathlib import Path

import behavior_lab as lab


class BehaviorLabTests(unittest.TestCase):
    def test_scenarios_are_unique_and_have_valid_commands(self):
        items = lab.scenarios()
        keys = [item.key for item in items]
        self.assertEqual(len(keys), len(set(keys)))
        allowed = set(lab.LANGUAGES) | {"rust", "fortran", "cobol"}
        for item in items:
            self.assertTrue(item.title)
            self.assertTrue(set(item.commands).issubset(allowed))
            self.assertEqual(set(item.commands), set(item.coverage))
            for steps in item.commands.values():
                for step in steps:
                    self.assertTrue(step.argv)
                    self.assertTrue(step.cwd.is_dir())

    def test_every_scenario_runs_in_all_four_languages(self):
        for item in lab.scenarios():
            for language in lab.LANGUAGES:
                self.assertTrue(item.commands[language], (item.key, language))
                self.assertNotEqual(item.coverage[language], "unsupported")

    def test_cell_status_prefers_failures(self):
        self.assertEqual(lab.cell_status([]), "unsupported")
        self.assertEqual(lab.cell_status([{"status": "passed"}]), "passed")
        self.assertEqual(
            lab.cell_status([{"status": "passed"}, {"status": "not_run"}]),
            "not_run",
        )
        self.assertEqual(
            lab.cell_status([{"status": "skipped"}, {"status": "failed"}]),
            "failed",
        )

    def test_summarize_counts_cells(self):
        results = [
            {
                "languages": {
                    "go": {"status": "passed"},
                    "python": {"status": "failed"},
                }
            },
            {
                "languages": {
                    "go": {"status": "unsupported"},
                    "python": {"status": "passed"},
                }
            },
        ]
        self.assertEqual(
            lab.summarize(results),
            {
                "cells": 4,
                "passed": 2,
                "failed": 1,
                "skipped": 0,
                "not_run": 0,
                "unsupported": 1,
            },
        )

    def test_exit_code_rejects_strict_not_run_and_skips(self):
        report = {"summary": {"failed": 0, "not_run": 1, "skipped": 0}}
        self.assertEqual(lab.exit_code(report, strict=False), 0)
        self.assertEqual(lab.exit_code(report, strict=True), 1)
        report = {"summary": {"failed": 0, "not_run": 0, "skipped": 1}}
        self.assertEqual(lab.exit_code(report, strict=True), 1)
        report = {"summary": {"failed": 0, "not_run": 0, "skipped": 0, "unsupported": 1}}
        self.assertEqual(lab.exit_code(report, strict=False), 0)
        self.assertEqual(lab.exit_code(report, strict=True), 1)
        report = {"summary": {"failed": 1, "not_run": 0, "skipped": 0}}
        self.assertEqual(lab.exit_code(report, strict=False), 1)

    def test_markdown_report_marks_group_coverage(self):
        report = {
            "run_id": "run-1",
            "started_at": "2026-10-30T00:00:00Z",
            "finished_at": "2026-10-30T00:00:01Z",
            "repository": {"sha": "a" * 40, "dirty": False},
            "summary": {
                "cells": 4,
                "passed": 3,
                "failed": 0,
                "skipped": 0,
                "not_run": 0,
                "unsupported": 1,
            },
            "scenarios": [
                {
                    "key": "initial-denial",
                    "languages": {
                        "go": {"status": "passed", "coverage": "scenario"},
                        "python": {"status": "passed", "coverage": "scenario"},
                        "typescript": {"status": "unsupported", "coverage": "unsupported"},
                        "java": {"status": "passed", "coverage": "group"},
                    },
                }
            ],
        }
        text = lab.markdown_report(report)
        self.assertIn("| initial-denial | passed (scenario) |", text)
        self.assertIn("unsupported (unsupported)", text)
        self.assertIn("passed (group)", text)
        self.assertIn("not complete feature parity", text)

    def test_write_report_keeps_each_run(self):
        def report(run_id):
            return {
                "schema": lab.SCHEMA,
                "run_id": run_id,
                "started_at": "2026-10-30T00:00:00Z",
                "finished_at": "2026-10-30T00:00:01Z",
                "repository": {"sha": "a" * 40, "dirty": False},
                "environment": {"platform": "test"},
                "selection": ["go"],
                "scenarios": [],
                "summary": {
                    "cells": 0,
                    "passed": 0,
                    "failed": 0,
                    "skipped": 0,
                    "not_run": 0,
                    "unsupported": 0,
                },
            }

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            first = lab.write_report(report("run-1"), output)
            second = lab.write_report(report("run-2"), output)
            self.assertTrue(first.is_file())
            self.assertTrue(second.is_file())
            self.assertNotEqual(first.parent, second.parent)
            latest = json.loads((output / "latest.json").read_text(encoding="utf-8"))
            self.assertEqual(latest["run_id"], "run-2")
            self.assertEqual(latest["report"], "run-2/report.json")

    def test_parse_languages_rejects_unknown_and_empty(self):
        self.assertEqual(lab.parse_languages("go,java", list(lab.LANGUAGES)), ["go", "java"])
        with self.assertRaises(ValueError):
            lab.parse_languages("go,cobol", list(lab.LANGUAGES))
        with self.assertRaises(ValueError):
            lab.parse_languages(" , ", list(lab.LANGUAGES))


if __name__ == "__main__":
    unittest.main()
