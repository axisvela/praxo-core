from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def maven_command():
    mvn = shutil.which("mvn")
    if mvn is None:
        raise AssertionError("Maven is required for the Java consumer test")
    if os.name == "nt" and mvn.lower().endswith((".cmd", ".bat")):
        return ["cmd", "/d", "/c", mvn]
    return [mvn]


class JavaConsumerTests(unittest.TestCase):
    def test_fresh_application_uses_maven_central_artifact(self):
        build = ROOT / "build"
        build.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="praxo-java-consumer-", dir=build) as directory:
            app = Path(directory)
            shutil.copy2(ROOT / "examples/consumer-java/pom.xml", app)
            shutil.copytree(ROOT / "examples/consumer-java/src", app / "src")
            maven = maven_command()
            commands = [
                [*maven, "-B", "test"],
                [*maven, "-B", "-q", "exec:java"],
            ]
            for command in commands:
                with self.subTest(command=command):
                    result = subprocess.run(
                        command, cwd=app,
                        capture_output=True, text=True, encoding="utf-8",
                        errors="replace", timeout=600,
                    )
                    self.assertEqual(
                        result.returncode, 0,
                        str(command) + "\n" + (result.stdout or "") + (result.stderr or ""),
                    )
                    if command[-1] == "test":
                        self.assertIn("GovernedAcceptanceTest", result.stdout or "")
                    if command[-1] == "exec:java":
                        lines = [line for line in result.stdout.splitlines() if line.strip()]
                        self.assertEqual(lines[-2:], [
                            "allow: recorded; effects=1",
                            "deny: policy rejected; effects=0",
                        ])


if __name__ == "__main__":
    unittest.main()
