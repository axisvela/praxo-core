from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import venv


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "praxo-core"


class PythonUpgradeTests(unittest.TestCase):
    def test_same_consumer_upgrades_without_source_changes(self):
        historical = (ROOT / "tests/consumer-python/requirements.txt").read_text(encoding="utf-8")
        baseline = re.search(r"^" + re.escape(PACKAGE) + r"==(\d+\.\d+\.\d+)\s*$",
                             historical, re.MULTILINE).group(1)
        packages = json.loads((ROOT / "docs/getting-started/agent-integration.json").read_text(encoding="utf-8"))
        current = next(item["version"] for item in packages["languages"] if item["language"] == "Python")
        self.assertNotEqual(baseline, current, "Upgrade evidence needs two distinct published versions")

        env = {
            key: value for key, value in os.environ.items()
            if key not in {"PYTHONPATH", "PYTHONHOME"} and not key.startswith("PIP_")
        }
        env["PIP_CONFIG_FILE"] = os.devnull
        with tempfile.TemporaryDirectory(prefix="praxo-python-upgrade-") as directory:
            app = Path(directory)
            files = ("starter.py", "test_starter.py", "test_governed.py")
            source = {name: (ROOT / "examples/consumer-python" / name).read_bytes() for name in files}
            for name in files:
                shutil.copy2(ROOT / "examples/consumer-python" / name, app / name)
            shutil.copy2(ROOT / "tests/consumer-python/test_governed_compat.py", app / "test_governed_compat.py")

            environment = app / ".venv"
            venv.create(environment, with_pip=True)
            python = environment / ("Scripts/python.exe" if sys.platform == "win32" else "bin/python")

            def run(*args, isolated=True):
                command = [str(python)]
                if isolated:
                    command.append("-I")
                command.extend(args)
                result = subprocess.run(
                    command, cwd=app, env=env,
                    capture_output=True, text=True, timeout=300,
                )
                self.assertEqual(result.returncode, 0,
                                 str(args) + "\n" + result.stdout + result.stderr)
                return result.stdout + result.stderr

            def install(version, upgrade=False):
                args = ["-m", "pip", "install", "--disable-pip-version-check",
                        "--only-binary=:all:", "--index-url", "https://pypi.org/simple"]
                if upgrade:
                    args.append("--upgrade")
                args.append(f"{PACKAGE}=={version}")
                run(*args)

            def installed_version():
                return run("-c", "import importlib.metadata; print(importlib.metadata.version('praxo-core'))").strip()

            install(baseline)
            self.assertEqual(installed_version(), baseline)
            baseline_tests = run(
                "-m", "unittest", "-v",
                "test_starter.StarterTests.test_allowed_tool",
                "test_starter.StarterTests.test_denied_tool_has_no_effect",
                "test_starter.StarterTests.test_starter_output",
                "test_governed_compat",
                isolated=False,
            )
            for name in ("test_allowed_tool", "test_denied_tool_has_no_effect",
                         "test_starter_output", "test_final_arguments_are_reauthorized"):
                self.assertIn(name, baseline_tests)

            install(current, upgrade=True)
            self.assertEqual(installed_version(), current)
            upgraded_tests = run("-m", "unittest", "discover", "-s", ".", "-v")
            for name in ("test_allowed_tool", "test_denied_tool_has_no_effect",
                         "test_starter_output", "test_published_dependency",
                         "test_final_arguments_are_reauthorized",
                         "test_approval_edit_is_reauthorized",
                         "test_policy_error_fails_closed"):
                self.assertIn(name, upgraded_tests)
            self.assertEqual(run("starter.py"),
                             "allow: recorded; effects=1\ndeny: policy rejected; effects=0\n")
            for name, original in source.items():
                self.assertEqual((app / name).read_bytes(), original, name)
            print(f"Published upgrade {PACKAGE} {baseline} -> {current}: "
                  "unchanged consumer, no replacements, governed checks passed")


if __name__ == "__main__":
    unittest.main()
