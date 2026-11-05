from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class GoConsumerTests(unittest.TestCase):
    def test_fresh_application_uses_published_package(self):
        go = shutil.which("go")
        self.assertIsNotNone(go, "Go is required for the consumer acceptance test")
        env = dict(os.environ, GOWORK="off")
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        with tempfile.TemporaryDirectory(prefix="praxo-consumer-") as directory:
            for filename in ("main.go", "main_test.go", "governed_test.go", "identity_test.go", "longrunning_test.go", "longrunning_http_test.go"):
                shutil.copy2(ROOT / "examples/consumer-go" / filename, directory)
            commands = [
                ["mod", "init", "example.com/praxo-starter"],
                ["get", "github.com/axisvela/praxo-core/v2@v" + version],
                ["mod", "tidy"],
                ["test", "-mod=readonly", "-v", "./..."],
                ["vet", "-mod=readonly", "./..."],
                ["build", "-mod=readonly", "./..."],
                ["run", "-mod=readonly", "."],
            ]
            for args in commands:
                with self.subTest(command=args):
                    result = subprocess.run(
                        [go, *args], cwd=directory, env=env,
                        capture_output=True, text=True, timeout=180,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    if args[0] == "test":
                        self.assertIn("TestGovernedReauthorizesFinalArguments", result.stdout)
                        self.assertIn("TestIdentityAllowsVerifiedOperator", result.stdout)
                        self.assertIn("TestLongRunningRunCancellationLeavesRemoteState", result.stdout)
                        self.assertIn("TestLongRunningSurvivesRestart", result.stdout)
                        self.assertIn("TestLongRunningHTTPResponseLossAndRestart", result.stdout)
                    if args[0] == "run":
                        self.assertEqual(
                            result.stdout,
                            "allow: recorded; effects=1\ndeny: policy rejected; effects=0\n",
                        )


if __name__ == "__main__":
    unittest.main()
