from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
RECIPE = ROOT / "examples/recipes/retry-go"


class GoRetryRecipeTests(unittest.TestCase):
    def test_fresh_application_uses_published_package(self):
        go = shutil.which("go")
        self.assertIsNotNone(go, "Go is required for the retry recipe test")
        env = dict(os.environ, GOWORK="off")
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        with tempfile.TemporaryDirectory(prefix="praxo-retry-") as directory:
            for source in RECIPE.glob("*.go"):
                shutil.copy2(source, directory)
            commands = [
                ["mod", "init", "example.com/praxo-retry"],
                ["get", "github.com/axisvela/praxo-core/v2@v" + version],
                ["mod", "tidy"],
                ["test", "-mod=readonly", "-run", "Retry|Blind|StatusAware", "-v", "./..."],
                ["vet", "-mod=readonly", "./..."],
            ]
            for args in commands:
                with self.subTest(command=args):
                    result = subprocess.run(
                        [go, *args], cwd=directory, env=env,
                        capture_output=True, text=True, timeout=180,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    if args[0] == "test":
                        for name in (
                            "TestRetryZeroValueUsesOneAttempt",
                            "TestRetryTransientWithPredicate",
                            "TestBlindRetryDuplicatesNonIdempotentEffect",
                            "TestStatusAwareRetryDoesNotDuplicateEffect",
                            "TestRetryStopsOnCancellation",
                        ):
                            self.assertIn(name, result.stdout)


if __name__ == "__main__":
    unittest.main()
