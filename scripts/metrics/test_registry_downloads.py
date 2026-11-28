import csv
import json
import tempfile
import unittest
from pathlib import Path

from scripts.metrics import registry_downloads as metrics


def fake_fetch(responses):
    def fetch(url):
        for prefix, payload in responses.items():
            if prefix in url:
                if isinstance(payload, Exception):
                    raise payload
                return json.dumps(payload).encode("utf-8")
        raise AssertionError(f"unexpected URL: {url}")

    return fetch


class RegistryDownloadTests(unittest.TestCase):
    def test_npm_and_crates_metrics_and_versions(self):
        targets = [
            metrics.Target("TypeScript", "@axisvela/praxo-core", "npm", "npm", "0.10.1", "", "published"),
            metrics.Target("Rust", "praxo-core", "crates.io", "crates", "0.11.1", "", "published"),
        ]
        fetch = fake_fetch(
            {
                "registry.npmjs.org/@axisvela%2Fpraxo-core/latest": {"version": "0.10.1"},
                "downloads/point/last-day/": {"downloads": 3},
                "downloads/point/last-week/": {"downloads": 20},
                "downloads/point/last-month/": {"downloads": 80},
                "api.npmjs.org/versions/": {"downloads": {"0.10.1": 20}},
                "crates.io/api/v1/crates/praxo-core": {
                    "crate": {"max_version": "0.11.1", "downloads": 100, "recent_downloads": 40},
                    "versions": [{"num": "0.11.1", "downloads": 60}],
                },
            }
        )
        result = metrics.collect_targets(targets, fetch, "2026-11-28T00:00:00Z")
        npm, crates = result
        self.assertEqual(npm["metrics"], {"total": None, "last_day": 3, "last_week": 20, "last_month": 80})
        self.assertEqual(npm["versions"], [{"version": "0.10.1", "downloads": 20}])
        self.assertEqual(crates["metrics"]["total"], 100)
        self.assertEqual(crates["metrics"]["last_month"], 40)
        self.assertEqual(crates["versions"][0]["downloads"], 60)

    def test_provider_error_is_recorded_per_target(self):
        target = metrics.Target("Python", "praxo-core", "PyPI", "pypi", "0.11.2", "", "published")
        result = metrics.collect_targets([target], lambda url: (_ for _ in ()).throw(RuntimeError("offline")), "now")
        self.assertEqual(result[0]["status"], "error")
        self.assertEqual(result[0]["metrics"], {name: None for name in metrics.METRIC_NAMES})
        self.assertIn("offline", result[0]["error"])

    def test_write_outputs_keeps_idempotent_series_and_summary(self):
        entries = [
            {
                "language": "Rust",
                "package": "praxo-core",
                "registry": "crates.io",
                "channel": "crates",
                "expected_version": "0.11.1",
                "version": "0.11.1",
                "status": "ok",
                "source": "test",
                "metrics": {"total": 100, "last_day": None, "last_week": None, "last_month": 40},
                "versions": [],
                "error": None,
                "collected_at": "2026-11-28T00:00:00Z",
            }
        ]
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            metrics.write_outputs(output, entries, "2026-11-28", "2026-11-28T00:00:00Z")
            metrics.write_outputs(output, entries, "2026-11-28", "2026-11-28T01:00:00Z")
            latest = json.loads((output / "latest.json").read_text(encoding="utf-8"))
            self.assertEqual(latest["targets"][0]["metrics"]["total"], 100)
            self.assertIn("Rust", (output / "summary.md").read_text(encoding="utf-8"))
            with (output / "series.csv").open(encoding="utf-8", newline="") as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(len(rows), 2)
            self.assertEqual({row["metric"] for row in rows}, {"total", "last_month"})
            self.assertEqual(metrics.check_outputs(output), [])

    def test_summary_groups_language_and_channel(self):
        entries = [
            {
                "language": "Elixir",
                "channel": "hex",
                "package": "praxo_core",
                "metrics": {"total": 10, "last_day": 1, "last_week": 2, "last_month": 3},
                "status": "ok",
            },
            {
                "language": "Erlang",
                "channel": "hex",
                "package": "praxo_core_erlang",
                "metrics": {"total": 5, "last_day": 0, "last_week": 1, "last_month": 2},
                "status": "ok",
            },
        ]
        summary = metrics.summarize(entries)
        self.assertEqual(summary["languages"]["Elixir"]["total"], 10)
        self.assertEqual(summary["channels"]["hex"]["total"], 15)
        self.assertEqual(summary["channels"]["hex"]["last_month"], 5)


if __name__ == "__main__":
    unittest.main()
