from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "@axisvela/praxo-core"


def npm_command():
    npm = shutil.which("npm")
    if npm is None:
        raise AssertionError("npm is required for the TypeScript upgrade test")
    if os.name == "nt" and npm.lower().endswith((".cmd", ".bat")):
        return ["cmd", "/d", "/c", npm]
    return [npm]


class TypeScriptUpgradeTests(unittest.TestCase):
    def test_same_consumer_upgrades_without_source_changes(self):
        baseline_package = json.loads(
            (ROOT / "tests/consumer-typescript/package.json").read_text(encoding="utf-8"))
        baseline = baseline_package["dependencies"][PACKAGE]
        packages = json.loads(
            (ROOT / "docs/getting-started/agent-integration.json").read_text(encoding="utf-8"))
        current = next(item["version"] for item in packages["languages"]
                       if item["language"] == "TypeScript")
        self.assertNotEqual(baseline, current,
                            "Upgrade evidence needs two distinct published versions")

        env = {
            key: value for key, value in os.environ.items()
            if not key.lower().startswith("npm_config_")
        }
        env["npm_config_update_notifier"] = "false"
        node = shutil.which("node")
        self.assertIsNotNone(node, "node is required for the TypeScript upgrade test")
        npm = npm_command()
        with tempfile.TemporaryDirectory(prefix="praxo-typescript-upgrade-") as directory:
            app = Path(directory)
            source_names = ("starter.js", "test_starter.test.js", "governed.test.js")
            source = {name: (ROOT / "language/typescript/examples/consumer" / name).read_bytes()
                      for name in source_names}
            source["test_governed_compat.test.js"] = (
                ROOT / "tests/consumer-typescript/test_governed_compat.test.js").read_bytes()
            for name in source_names:
                shutil.copy2(ROOT / "language/typescript/examples/consumer" / name, app / name)
            shutil.copy2(ROOT / "tests/consumer-typescript/test_governed_compat.test.js",
                         app / "test_governed_compat.test.js")
            shutil.copy2(ROOT / "tests/consumer-typescript/package.json", app / "package.json")

            def run(*args, expected_env=None):
                command_env = dict(env)
                if expected_env:
                    command_env.update(expected_env)
                result = subprocess.run(
                    [*args], cwd=app, env=command_env,
                    capture_output=True, text=True, encoding="utf-8",
                    errors="replace", timeout=300,
                )
                self.assertEqual(result.returncode, 0,
                                 str(args) + "\n" + (result.stdout or "") + (result.stderr or ""))
                return (result.stdout or "") + (result.stderr or "")

            def install(version):
                run(*npm, "install", "--no-audit", "--no-fund", "--ignore-scripts",
                    "--registry", "https://registry.npmjs.org/",
                    "--save-exact", f"{PACKAGE}@{version}")

            def installed_version():
                return run(node, "-e",
                           f"console.log(require('{PACKAGE}/package.json').version)").strip()

            install(baseline)
            self.assertEqual(installed_version(), baseline)
            baseline_tests = run(
                node, "--test", "test_starter.test.js", "test_governed_compat.test.js",
                expected_env={"PRAXO_EXPECTED_VERSION": baseline},
            )
            for name in ("allowed tool executes once", "denied tool has no effect",
                         "starter output is deterministic", "final arguments are reauthorized"):
                self.assertIn(name, baseline_tests)

            install(current)
            self.assertEqual(installed_version(), current)
            upgraded_tests = run(
                *npm, "test", "--silent",
                expected_env={"PRAXO_EXPECTED_VERSION": current},
            )
            for name in ("allowed tool executes once", "denied tool has no effect",
                         "starter output is deterministic",
                         "dependency comes from the published package",
                         "final arguments are reauthorized",
                         "approval edit is reauthorized",
                         "policy error fails closed"):
                self.assertIn(name, upgraded_tests)
            self.assertEqual(run(node, "starter.js"),
                             "allow: recorded; effects=1\ndeny: policy rejected; effects=0\n")
            for name, original in source.items():
                self.assertEqual((app / name).read_bytes(), original, name)
            print(f"Published upgrade {PACKAGE} {baseline} -> {current}: "
                  "unchanged consumer, no replacements, governed checks passed")


if __name__ == "__main__":
    unittest.main()
