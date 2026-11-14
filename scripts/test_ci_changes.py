import json
import os
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def classify(files):
    env = dict(os.environ)
    env["CI_CHANGED_FILES"] = "\n".join(files)
    result = subprocess.run(
        [sys.executable, "scripts/ci_changes.py"],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr)
    values = {}
    for line in result.stdout.splitlines():
        key, value = line.split("=", 1)
        values[key] = value
    return values


class CiChangesTests(unittest.TestCase):
    def test_language_change_does_not_run_core(self):
        values = classify(["language/python/praxo/agent.py"])
        self.assertEqual(values["core"], "false")
        self.assertEqual(json.loads(values["languages"]), ["python"])

    def test_core_go_change_runs_core(self):
        values = classify(["pkg/agent/agent.go"])
        self.assertEqual(values["core"], "true")
        self.assertEqual(json.loads(values["languages"]), [])

    def test_example_go_change_does_not_run_core(self):
        values = classify(["examples/embedded-service/main.go"])
        self.assertEqual(values["examples"], "true")
        self.assertEqual(values["core"], "false")

    def test_consumer_change_does_not_run_core(self):
        values = classify(["language/python/examples/consumer/starter.py"])
        self.assertEqual(values["consumers"], "false")
        self.assertEqual(values["core"], "false")
        self.assertEqual(json.loads(values["languages"]), ["python"])

    def test_go_consumer_change_does_not_run_core(self):
        values = classify(["language/go/examples/consumer-go/main.go"])
        self.assertEqual(values["consumers"], "true")
        self.assertEqual(values["core"], "false")

    def test_spec_change_runs_full_matrix(self):
        values = classify(["spec/vectors/agent.json"])
        self.assertEqual(values["full"], "true")
        self.assertEqual(values["core"], "true")


if __name__ == "__main__":
    unittest.main()
