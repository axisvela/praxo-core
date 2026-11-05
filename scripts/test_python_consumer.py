from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import venv


ROOT = Path(__file__).resolve().parents[1]


class PythonConsumerTests(unittest.TestCase):
    def test_fresh_application_uses_pypi_package(self):
        env = {
            key: value for key, value in os.environ.items()
            if key not in {"PYTHONPATH", "PYTHONHOME"} and not key.startswith("PIP_")
        }
        env["PIP_CONFIG_FILE"] = os.devnull
        with tempfile.TemporaryDirectory(prefix="praxo-python-consumer-") as directory:
            app = Path(directory)
            for filename in ("starter.py", "test_starter.py", "requirements.txt"):
                shutil.copy2(ROOT / "examples/consumer-python" / filename, app)
            environment = app / ".venv"
            venv.create(environment, with_pip=True)
            python = environment / ("Scripts/python.exe" if sys.platform == "win32" else "bin/python")
            commands = [
                ["-m", "pip", "install", "--disable-pip-version-check", "--only-binary=:all:",
                 "--index-url", "https://pypi.org/simple", "-r", "requirements.txt"],
                ["-m", "pip", "check"],
                ["-m", "unittest", "discover", "-s", ".", "-v"],
                ["starter.py"],
            ]
            for args in commands:
                result = subprocess.run(
                    [str(python), "-I", *args], cwd=app, env=env,
                    capture_output=True, text=True, timeout=180,
                )
                self.assertEqual(result.returncode, 0, str(args) + "\n" + result.stdout + result.stderr)
                if args == ["starter.py"]:
                    self.assertEqual(result.stdout, "allow: recorded; effects=1\ndeny: policy rejected; effects=0\n")


if __name__ == "__main__":
    unittest.main()
