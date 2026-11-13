from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def npm_command():
    npm = shutil.which("npm")
    if npm is None:
        raise AssertionError("npm is required for the TypeScript consumer test")
    if os.name == "nt" and npm.lower().endswith((".cmd", ".bat")):
        return ["cmd", "/d", "/c", npm]
    return [npm]


class TypeScriptConsumerTests(unittest.TestCase):
    def test_fresh_application_uses_npm_package(self):
        env = {
            key: value for key, value in os.environ.items()
            if not key.lower().startswith("npm_config_")
        }
        env["npm_config_update_notifier"] = "false"
        with tempfile.TemporaryDirectory(prefix="praxo-typescript-consumer-") as directory:
            app = Path(directory)
            for filename in ("package.json", "package-lock.json", "starter.js", "test_starter.test.js", "governed.test.js"):
                shutil.copy2(ROOT / "language/typescript/examples/consumer" / filename, app)
            npm = npm_command()
            commands = [
                [*npm, "ci", "--no-audit", "--no-fund", "--ignore-scripts",
                 "--registry", "https://registry.npmjs.org/"],
                [*npm, "test", "--silent"],
                [shutil.which("node"), "starter.js"],
            ]
            for command in commands:
                with self.subTest(command=command):
                    result = subprocess.run(
                        command, cwd=app, env=env,
                        capture_output=True, text=True, encoding="utf-8",
                        errors="replace", timeout=180,
                    )
                    self.assertEqual(result.returncode, 0, str(command) + "\n" + (result.stdout or "") + (result.stderr or ""))
                    if command[-2:] == ["test", "--silent"]:
                        output = (result.stdout or "") + (result.stderr or "")
                        self.assertIn("final arguments are reauthorized", output)
                        self.assertIn("approval edit is reauthorized", output)
                    if command[-1] == "starter.js":
                        self.assertIn(
                            "allow: recorded; effects=1\ndeny: policy rejected; effects=0\n",
                            result.stdout,
                        )


if __name__ == "__main__":
    unittest.main()
