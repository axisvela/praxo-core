import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

import adoption_baseline as baseline


def task(**changes):
    value = {
        "id": "regression-001",
        "kind": "regression",
        "track": "free-selection",
        "suitable": True,
        "prompt": "Add a governed agent loop with an approval step.",
        "packageVersion": "2.6.0",
        "acceptance": ["the loop runs", "approval is required"],
    }
    value.update(changes)
    return value


def manifest(**changes):
    value = {
        "schemaVersion": 1,
        "protocol": "docs/project/adoption-baseline.md",
        "tool": {"name": "example-tool", "version": "1.0.0"},
        "model": {"name": "example-model", "version": "2026-11-01"},
        "environment": {
            "os": "linux",
            "toolchain": "go1.25.0",
            "permissions": {"search": True, "execute": True},
        },
        "budgets": {"maxSteps": 20, "timeoutSeconds": 600},
        "tasks": [task()],
    }
    value.update(changes)
    return value


class AdoptionManifestTests(unittest.TestCase):
    def test_valid_manifest_reports_kind_and_track_counts(self):
        data = manifest(
            tasks=[
                task(),
                task(id="unseen-001", kind="unseen", track="directed-integration", prompt="Use PRAXO-CORE."),
                task(
                    id="upgrade-001",
                    kind="regression",
                    track="upgrade-maintenance",
                    baselineVersion="2.5.0",
                    targetVersion="2.6.0",
                    packageVersion="2.5.0",
                ),
            ]
        )
        counts = baseline.validate_manifest(data)
        self.assertEqual(counts[("regression", "free-selection")], 1)
        self.assertEqual(counts[("unseen", "directed-integration")], 1)
        self.assertEqual(counts[("regression", "upgrade-maintenance")], 1)

    def test_missing_top_level_field_is_rejected(self):
        data = manifest()
        del data["budgets"]
        with self.assertRaisesRegex(baseline.ManifestError, "budgets: required"):
            baseline.validate_manifest(data)

    def test_duplicate_task_id_is_rejected(self):
        data = manifest(tasks=[task(), task()])
        with self.assertRaisesRegex(baseline.ManifestError, "duplicate 'regression-001'"):
            baseline.validate_manifest(data)

    def test_unknown_track_and_kind_are_rejected(self):
        data = manifest(tasks=[task(track="unknown", kind="exploratory")])
        with self.assertRaises(baseline.ManifestError) as caught:
            baseline.validate_manifest(data)
        message = str(caught.exception)
        self.assertIn("kind: one of", message)
        self.assertIn("track: one of", message)

    def test_free_selection_prompt_must_not_name_the_framework(self):
        data = manifest(tasks=[task(prompt="Add PRAXO-CORE to this project.")])
        with self.assertRaisesRegex(baseline.ManifestError, "must not name PRAXO-CORE"):
            baseline.validate_manifest(data)

    def test_directed_integration_prompt_must_name_the_framework(self):
        data = manifest(tasks=[task(track="directed-integration")])
        with self.assertRaisesRegex(baseline.ManifestError, "must name PRAXO-CORE"):
            baseline.validate_manifest(data)

    def test_upgrade_task_requires_baseline_and_target_versions(self):
        data = manifest(tasks=[task(track="upgrade-maintenance")])
        with self.assertRaises(baseline.ManifestError) as caught:
            baseline.validate_manifest(data)
        message = str(caught.exception)
        self.assertIn("baselineVersion: non-empty string required", message)
        self.assertIn("targetVersion: non-empty string required", message)

    def test_budgets_must_be_positive_integers(self):
        data = manifest(budgets={"maxSteps": 0, "timeoutSeconds": -1})
        with self.assertRaises(baseline.ManifestError) as caught:
            baseline.validate_manifest(data)
        message = str(caught.exception)
        self.assertIn("budgets.maxSteps: positive integer required", message)
        self.assertIn("budgets.timeoutSeconds: positive integer required", message)

    def test_cli_returns_nonzero_for_invalid_manifest(self):
        data = manifest(budgets={"maxSteps": 0, "timeoutSeconds": 600})
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            stderr = io.StringIO()
            with contextlib.redirect_stderr(stderr):
                result = baseline.main([str(path)])
        self.assertEqual(result, 1)
        self.assertIn("budgets.maxSteps", stderr.getvalue())

    def test_cli_returns_zero_for_valid_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps(manifest()), encoding="utf-8")
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                result = baseline.main([str(path)])
        self.assertEqual(result, 0)
        self.assertIn("adoption manifest valid: 1 tasks", stdout.getvalue())


if __name__ == "__main__":
    unittest.main()
