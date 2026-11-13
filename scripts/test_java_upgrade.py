from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def maven_command():
    mvn = shutil.which("mvn")
    if mvn is None:
        raise AssertionError("Maven is required for the Java upgrade test")
    if os.name == "nt" and mvn.lower().endswith((".cmd", ".bat")):
        return ["cmd", "/d", "/c", mvn]
    return [mvn]


class JavaUpgradeTests(unittest.TestCase):
    def test_same_consumer_upgrades_without_source_changes(self):
        baseline = (ROOT / "tests/consumer-java/baseline.txt").read_text(encoding="utf-8").strip()
        packages = json.loads(
            (ROOT / "docs/getting-started/agent-integration.json").read_text(encoding="utf-8"))
        current = next(item["version"] for item in packages["languages"]
                       if item["language"] == "Java")
        self.assertNotEqual(baseline, current,
                            "Upgrade evidence needs two distinct published versions")

        current_pom = (ROOT / "language/java/examples/consumer/pom.xml").read_text(encoding="utf-8")
        marker = f"<version>{current}</version>"
        self.assertIn(marker, current_pom, "Java starter pom must declare the package-map version")
        baseline_pom = current_pom.replace(marker, f"<version>{baseline}</version>", 1)

        build = ROOT / "build"
        build.mkdir(exist_ok=True)
        maven = maven_command()
        with tempfile.TemporaryDirectory(prefix="praxo-java-upgrade-", dir=build) as directory:
            app = Path(directory)
            baseline_sources = (
                "src/main/java/starter/App.java",
                "src/test/java/starter/AppTest.java",
            )
            for name in baseline_sources:
                target = app / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "language/java/examples/consumer" / name, target)
            compat = "src/test/java/starter/GovernedCompatTest.java"
            (app / compat).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / "tests/consumer-java" / compat, app / compat)
            (app / "pom.xml").write_text(baseline_pom, encoding="utf-8")

            source = {name: (app / name).read_bytes() for name in (*baseline_sources, compat)}

            def run(*args):
                result = subprocess.run(
                    [*args], cwd=app,
                    capture_output=True, text=True, encoding="utf-8",
                    errors="replace", timeout=900,
                )
                self.assertEqual(result.returncode, 0,
                                 str(args) + "\n" + (result.stdout or "") + (result.stderr or ""))
                return (result.stdout or "") + (result.stderr or "")

            baseline_tests = run(
                *maven, "-B", "test",
                "-Dtest=AppTest#allowedToolRunsOnce+deniedToolHasNoEffect+starterOutputIsDeterministic,GovernedCompatTest",
            )
            self.assertIn("starter.AppTest", baseline_tests)
            self.assertIn("Tests run: 3", baseline_tests)
            self.assertIn("starter.GovernedCompatTest", baseline_tests)
            self.assertIn("Tests run: 4", baseline_tests)
            self.assertNotIn("Failures: 1", baseline_tests)

            hitl = "src/test/java/starter/GovernedAcceptanceTest.java"
            shutil.copy2(ROOT / "language/java/examples/consumer" / hitl, app / hitl)
            hitl_source = (app / hitl).read_bytes()
            (app / "pom.xml").write_text(current_pom, encoding="utf-8")
            upgraded_tests = run(*maven, "-B", "test")
            for name in ("AppTest", "GovernedAcceptanceTest", "GovernedCompatTest"):
                self.assertIn(name, upgraded_tests)
            output = run(*maven, "-B", "-q", "exec:java")
            lines = [line.strip() for line in output.splitlines() if line.strip()]
            allow_index = lines.index("allow: recorded; effects=1")
            deny_index = lines.index("deny: policy rejected; effects=0")
            self.assertLess(allow_index, deny_index)
            for name, original in source.items():
                self.assertEqual((app / name).read_bytes(), original, name)
            self.assertEqual((app / hitl).read_bytes(), hitl_source)
            print(f"Published upgrade com.axisvela:praxo-core {baseline} -> {current}: "
                  "unchanged consumer, no replacements, governed checks passed")


if __name__ == "__main__":
    unittest.main()
