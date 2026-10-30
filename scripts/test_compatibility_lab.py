import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import compatibility_lab as lab


class CompatibilityLabTests(unittest.TestCase):
    def test_language_definitions_are_stable(self):
        languages = lab.language_definitions()
        self.assertTrue(set(lab.DEFAULT_LANGUAGES).issubset(languages))
        self.assertIn("fortran", languages)
        self.assertIn("cobol", languages)
        for item in languages.values():
            self.assertTrue(item.version)
            self.assertTrue(item.run)
            for step in (*item.install, *item.run):
                self.assertTrue(step.argv)
                self.assertTrue(step.cwd.is_dir())

    def test_parse_languages_rejects_unknown_and_empty(self):
        languages = lab.language_definitions()
        self.assertEqual(lab.parse_languages("python,rust", languages), ["python", "rust"])
        with self.assertRaises(ValueError):
            lab.parse_languages("python,nope", languages)
        with self.assertRaises(ValueError):
            lab.parse_languages(" , ", languages)

    def test_summarize_counts_statuses(self):
        report = lab.summarize(
            [
                {"status": "passed"},
                {"status": "passed"},
                {"status": "failed"},
                {"status": "skipped"},
            ]
        )
        self.assertEqual(
            report,
            {
                "total": 4,
                "passed": 2,
                "failed": 1,
                "skipped": 1,
                "not_run": 0,
                "commands_not_run": 0,
            },
        )

    def test_exit_code_honors_strict_skips(self):
        report = {"summary": {"failed": 0, "skipped": 1}}
        self.assertEqual(lab.exit_code(report, strict=False), 0)
        self.assertEqual(lab.exit_code(report, strict=True), 1)
        report = {"summary": {"failed": 1, "skipped": 0}}
        self.assertEqual(lab.exit_code(report, strict=False), 1)

    def test_markdown_report_lists_languages_and_limits(self):
        report = {
            "run_id": "20261030T000000Z-test",
            "started_at": "2026-10-30T00:00:00Z",
            "finished_at": "2026-10-30T00:00:01Z",
            "repository": {"sha": "a" * 40, "dirty": False},
            "environment": {"platform": "test"},
            "summary": {
                "total": 1,
                "passed": 1,
                "failed": 0,
                "skipped": 0,
                "not_run": 0,
                "commands_not_run": 0,
            },
            "languages": [
                {
                    "name": "Python",
                    "status": "passed",
                    "version": "Python 3",
                    "reason": None,
                    "commands": [{"label": "conformance"}],
                }
            ],
        }
        text = lab.markdown_report(report)
        self.assertIn("| Python | passed |", text)
        self.assertIn("not", text)
        self.assertIn("provider, production, or security verification", text)

    def test_missing_executable_is_skipped(self):
        item = lab.Command(
            "missing",
            ("definitely-not-a-praxo-command",),
            lab.ROOT,
        )
        result = lab.run_command(item, 10)
        self.assertEqual(result["status"], "skipped")
        self.assertIn("executable not found", result["reason"])

    def test_run_command_records_success_and_failure(self):
        success = lab.run_command(
            lab.Command("success", (sys.executable, "-c", "print('ok')"), lab.ROOT),
            30,
        )
        self.assertEqual(success["status"], "passed")
        self.assertEqual(success["exit_code"], 0)
        self.assertIn("ok", success["stdout"])

        failure = lab.run_command(
            lab.Command("failure", (sys.executable, "-c", "raise SystemExit(9)"), lab.ROOT),
            30,
        )
        self.assertEqual(failure["status"], "failed")
        self.assertEqual(failure["exit_code"], 9)

    def test_language_stops_after_failed_step(self):
        item = lab.Language(
            "fixture",
            "Fixture",
            (sys.executable, "--version"),
            (),
            (
                lab.Command("failure", (sys.executable, "-c", "raise SystemExit(7)"), lab.ROOT),
                lab.Command("never", (sys.executable, "-c", "print('never')"), lab.ROOT),
            ),
        )
        result = lab.run_language(item, 30, install=False)
        self.assertEqual(result["status"], "failed")
        self.assertEqual(len(result["commands"]), 2)
        self.assertEqual(result["commands"][0]["label"], "failure")
        self.assertEqual(result["commands"][1]["status"], "not_run")
        self.assertEqual(result["commands"][1]["reason"], "not run because a previous command did not pass")

    def test_timeout_bytes_are_decoded(self):
        error = subprocess.TimeoutExpired(
            ["fixture"], 1, output=b"partial out", stderr=b"partial err"
        )
        item = lab.Command(
            "timeout", (sys.executable, "-c", "pass"), lab.ROOT
        )
        with patch.object(lab.subprocess, "run", side_effect=error):
            result = lab.run_command(item, 1)
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["stdout"], "partial out")
        self.assertEqual(result["stderr"], "partial err")

    def test_report_metadata_is_captured_before_run(self):
        item = lab.Language(
            "fixture",
            "Fixture",
            (sys.executable, "--version"),
            (),
            (lab.Command("ok", (sys.executable, "-c", "pass"), lab.ROOT),),
        )
        result = lab.run_language(item, 30, install=False)
        report = lab.build_report(
            ["fixture"],
            [result],
            "run-id",
            "2026-10-30T00:00:00Z",
            "2026-10-30T00:00:01Z",
            {"sha": "a" * 40, "dirty": False},
        )
        self.assertEqual(report["run_id"], "run-id")
        self.assertEqual(report["started_at"], "2026-10-30T00:00:00Z")
        self.assertEqual(report["finished_at"], "2026-10-30T00:00:01Z")
        self.assertEqual(report["repository"]["sha"], "a" * 40)

    def test_write_report_keeps_each_run(self):
        def report(run_id):
            return {
                "schema": lab.SCHEMA,
                "run_id": run_id,
                "started_at": "2026-10-30T00:00:00Z",
                "finished_at": "2026-10-30T00:00:01Z",
                "repository": {"sha": "a" * 40, "dirty": False},
                "environment": {"platform": "test"},
                "selection": ["fixture"],
                "languages": [],
                "summary": {
                    "total": 0,
                    "passed": 0,
                    "failed": 0,
                    "skipped": 0,
                    "not_run": 0,
                    "commands_not_run": 0,
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


if __name__ == "__main__":
    unittest.main()
