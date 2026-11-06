import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import execution_correctness as ec


def selector(name="TestA", package="./pkg/agent", scenario="EC-04", full=None):
    full = full or name
    return ec.Selector(scenario, package, name, full, "fixture assertion")


def events(selectors, action="pass"):
    result = []
    for item in selectors:
        result.append({"Action": "run", "Test": item.selector, "Package": item.package})
        result.append({"Action": action, "Test": item.selector, "Package": item.package, "Elapsed": 0.01})
    return result


def package_run(package="./pkg/agent", *, action="pass", exit_code=0, malformed=None, timed_out=False, error=None):
    return {
        "package": package,
        "command": ["go", "test"],
        "exitCode": exit_code,
        "timedOut": timed_out,
        "error": error,
        "elapsedMs": 1,
        "events": events([selector(package=package)], action=action),
        "malformed": malformed or [],
        "stdout": "",
        "stderr": "",
    }


class ExecutionCorrectnessRunnerTests(unittest.TestCase):
    def test_parse_events_separates_malformed_lines(self):
        text = "\n".join([
            json.dumps({"Action": "pass", "Test": "TestA"}),
            "build failed: not json",
            json.dumps({"not": "an action"}),
        ])
        parsed, malformed = ec.parse_events(text)
        self.assertEqual(len(parsed), 1)
        self.assertEqual([item["line"] for item in malformed], ["2", "3"])

    def test_scope_passes_only_when_all_required_selectors_pass(self):
        item = selector()
        result = ec.evaluate([item], [package_run()])
        self.assertEqual(result["status"], "scope-passed")
        self.assertEqual(result["counts"], {
            "required": 1, "passed": 1, "failed": 0, "skipped": 0, "not-run": 0, "blocked": 0,
        })

    def test_missing_subtest_is_not_run_and_does_not_pass(self):
        required = selector("TestA", full="TestA/sub")
        run = package_run()
        run["events"] = [{"Action": "pass", "Test": "TestA", "Package": "./pkg/agent"}]
        result = ec.evaluate([required], [run])
        self.assertEqual(result["status"], "scope-failed")
        self.assertEqual(result["results"][0]["outcome"], "not-run")

    def test_fail_and_skip_are_not_passed(self):
        item = selector()
        failed = package_run(action="fail")
        self.assertEqual(ec.evaluate([item], [failed])["results"][0]["outcome"], "failed")
        skipped = package_run(action="skip")
        self.assertEqual(ec.evaluate([item], [skipped])["results"][0]["outcome"], "skipped")

    def test_malformed_output_blocks_the_package(self):
        item = selector()
        run = package_run()
        run["malformed"] = [{"line": "1", "text": "bad"}]
        result = ec.evaluate([item], [run])
        self.assertEqual(result["status"], "scope-failed")
        self.assertEqual(result["results"][0]["outcome"], "blocked")
        self.assertEqual(result["packages"][0]["status"], "invalid")

    def test_failed_package_without_terminal_is_blocked(self):
        item = selector()
        run = package_run(exit_code=1)
        run["events"] = []
        result = ec.evaluate([item], [run])
        self.assertEqual(result["results"][0]["outcome"], "blocked")
        self.assertEqual(result["status"], "scope-failed")

    def test_timeout_blocks_the_package(self):
        item = selector()
        run = package_run(timed_out=True)
        run["events"] = []
        result = ec.evaluate([item], [run])
        self.assertEqual(result["results"][0]["outcome"], "blocked")
        self.assertEqual(result["packages"][0]["status"], "blocked")

    def test_duplicate_selectors_are_invalid(self):
        item = selector()
        result = ec.evaluate([item, item], [package_run()])
        self.assertEqual(result["status"], "invalid")
        self.assertTrue(result["errors"])

    def test_command_selects_only_named_parent_tests(self):
        command = ec.build_command("go", "./pkg/agent", ["TestB", "TestA"], 30)
        self.assertEqual(command[:-1], [
            "go", "test", "-json", "-count=1", "-timeout", "30s", "-run", "^(?:TestA|TestB)$",
        ])
        self.assertEqual(command[-1], "./pkg/agent")

    def test_inventory_scope_contains_exact_subtests(self):
        inventory = ec.load_inventory(ec.DEFAULT_INVENTORY)
        selectors, scope = ec.select_scope(inventory, "core-mechanics-baseline")
        names = {item.selector for item in selectors}
        self.assertEqual(scope["name"], "core-mechanics-baseline")
        self.assertIn("TestFinalToolArgumentsAuthorized/middleware/deny/1", names)
        self.assertIn("TestRunStopsStartingToolsAfterCancellation/sequential", names)
        self.assertIn("TestRunCompletionCallbackFailureHasSingleTerminalEvent/completed", names)

    def test_missing_go_is_rejected(self):
        with patch.object(ec.shutil, "which", return_value=None):
            with self.assertRaises(ec.RunnerError):
                ec.resolve_go("definitely-not-a-praxo-go")

    def test_report_directories_are_unique_and_keep_latest(self):
        report = {
            "schema": ec.SCHEMA,
            "runId": "20261106T000000Z-fixture",
            "startedAt": "2026-11-06T00:00:00Z",
            "finishedAt": "2026-11-06T00:00:01Z",
            "status": "scope-passed",
            "scope": {"name": "fixture", "track": "EC-D"},
            "claim": "fixture",
            "inventory": {"sha256": "a" * 64, "designCommit": "b" * 40},
            "repository": {"sha": "c" * 40, "dirty": False},
            "toolchain": {"goVersion": "go version fixture"},
            "environment": {"platform": "fixture"},
            "packages": [{"package": "./pkg/agent", "status": "passed", "exitCode": 0,
                          "timedOut": False, "eventCount": 1, "malformedCount": 0}],
            "selectors": [{"scenario": "EC-04", "selector": "TestA", "outcome": "passed",
                           "package": "./pkg/agent"}],
            "counts": {"required": 1, "passed": 1, "failed": 0, "skipped": 0,
                       "not-run": 0, "blocked": 0},
            "errors": [],
            "limitations": ["fixture limitation"],
        }
        run = {
            "package": "./pkg/agent",
            "events": [{"Action": "pass", "Test": "TestA"}],
            "stdout": "stdout",
            "stderr": "stderr",
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = ec.write_report(report, [run], root)
            second = ec.write_report(report, [run], root)
            self.assertNotEqual(first, second)
            self.assertTrue((first / "report.json").is_file())
            self.assertTrue((second / "report.md").is_file())
            latest = json.loads((root / "latest.json").read_text(encoding="utf-8"))
            self.assertEqual(latest["runId"], report["runId"])
            self.assertEqual(latest["path"], second.name)

    def test_exit_code_is_strict_for_scope_failures(self):
        self.assertEqual(ec.exit_code("scope-passed"), 0)
        self.assertEqual(ec.exit_code("scope-failed", strict=True), 1)
        self.assertEqual(ec.exit_code("scope-failed", strict=False), 0)
        self.assertEqual(ec.exit_code("invalid", strict=False), 2)


if __name__ == "__main__":
    unittest.main()
