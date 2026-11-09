from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
MONITORING = ROOT / "examples/recipes/long-running-go/monitoring"


class LongRunningMonitoringTests(unittest.TestCase):
    def test_prometheus_scrape_config(self):
        config = yaml.safe_load((MONITORING / "prometheus.yml").read_text(encoding="utf-8"))
        self.assertIn("alerts.yml", config["rule_files"])
        self.assertTrue(config["global"]["scrape_interval"])
        jobs = config["scrape_configs"]
        self.assertEqual(len(jobs), 1)
        self.assertEqual(jobs[0]["job_name"], "praxo-longrunning")
        self.assertIn("127.0.0.1:8080", jobs[0]["static_configs"][0]["targets"])

    def test_alert_rules_use_service_metrics(self):
        alerts = yaml.safe_load((MONITORING / "alerts.yml").read_text(encoding="utf-8"))
        rules = alerts["groups"][0]["rules"]
        names = {rule["alert"]: rule for rule in rules}
        self.assertIn("PraxoLongRunningErrors", names)
        self.assertIn("PraxoLongRunningDown", names)
        self.assertIn("PraxoLongRunningNoOperations", names)
        self.assertIn("praxo_longrunning_http_errors_total", names["PraxoLongRunningErrors"]["expr"])
        self.assertIn("up{", names["PraxoLongRunningDown"]["expr"])
        self.assertIn("praxo_longrunning_operations_total", names["PraxoLongRunningNoOperations"]["expr"])
        for rule in rules:
            self.assertTrue(rule.get("for"))
            self.assertTrue(rule["labels"]["severity"])

    def test_retention_is_configured(self):
        args = (MONITORING / "prometheus.args").read_text(encoding="utf-8").splitlines()
        self.assertIn("--config.file=prometheus.yml", args)
        retention = [line for line in args if line.startswith("--storage.tsdb.retention.time=")]
        self.assertEqual(len(retention), 1)


if __name__ == "__main__":
    unittest.main()
