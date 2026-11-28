import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest

import build_php_package as package


class PhpPackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="praxo-php-package-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.output = self.root / "split"
        self.version, self.files = package.payload()

    def canonical_fixture(self):
        canonical = self.root / "canonical"
        sdk = canonical / "language/php"
        for name in (*package.DOCUMENTS, "composer.json"):
            target = sdk / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(package.ROOT / "language/php" / name, target)
        for name in ("src", "api"):
            shutil.copytree(package.ROOT / "language/php" / name, sdk / name)
        return canonical

    def test_recursive_exact_payload_and_metadata(self):
        package.stage(self.output, self.files)
        package.check(self.output, self.files)
        metadata = json.loads((self.output / "composer.json").read_text())
        self.assertNotIn("version", metadata)
        self.assertNotIn("scripts", metadata)
        self.assertEqual(metadata["autoload"]["files"], ["src/autoload.php"])
        self.assertIn("praxocore", metadata["description"])
        self.assertIn("agent-framework", metadata["keywords"])
        self.assertIn("laravel", metadata["keywords"])
        self.assertNotIn("drupal", metadata["keywords"])
        sdk = package.ROOT / "language/php"
        for path in (sdk / "src").rglob("*"):
            if path.is_file():
                self.assertEqual((self.output / path.relative_to(sdk)).read_bytes(), path.read_bytes())
        self.assertIn("src/PluginProcessHost.php", self.files)
        self.assertIn("src/Adapters/OpenAICompatible.php", self.files)

    def test_new_nested_runtime_file_is_automatically_included(self):
        canonical = self.canonical_fixture()
        nested = canonical / "language/php/src/Future/Nested.php"
        nested.parent.mkdir()
        nested.write_bytes(b"<?php\n")
        _, files = package.payload(canonical)
        self.assertEqual(files["src/Future/Nested.php"], b"<?php\n")

    def test_missing_canonical_plugin_fails_build(self):
        canonical = self.canonical_fixture()
        (canonical / "language/php/src/PluginProcessHost.php").unlink()
        with self.assertRaisesRegex(ValueError, "Missing required package input"):
            package.payload(canonical)

    def test_check_rejects_missing_changed_and_stale_files(self):
        package.stage(self.output, self.files)
        plugin = self.output / "src/PluginProcessHost.php"
        plugin.unlink()
        with self.assertRaisesRegex(ValueError, "missing=.*PluginProcessHost"):
            package.check(self.output, self.files)
        plugin.write_bytes(b"<?php\n")
        with self.assertRaisesRegex(ValueError, "changed=.*PluginProcessHost"):
            package.check(self.output, self.files)
        plugin.write_bytes(self.files["src/PluginProcessHost.php"])
        (self.output / "stale.php").write_bytes(b"<?php\n")
        with self.assertRaisesRegex(ValueError, "extra=.*stale.php"):
            package.check(self.output, self.files)

    def test_stage_refuses_existing_work_and_check_allows_git(self):
        package.stage(self.output, self.files)
        with self.assertRaisesRegex(ValueError, "Refusing to overwrite"):
            package.stage(self.output, self.files)
        (self.output / ".git").mkdir()
        (self.output / ".git/config").write_bytes(b"local git metadata")
        package.check(self.output, self.files)

    def test_isolated_composer_consumer_and_missing_plugin_regression(self):
        php = os.environ.get("PRAXO_PHP") or shutil.which("php")
        composer = os.environ.get("PRAXO_COMPOSER") or shutil.which("composer")
        self.assertTrue(php, "Set PRAXO_PHP to the PHP executable")
        self.assertTrue(composer, "Set PRAXO_COMPOSER to composer.phar or Composer executable")
        php_command = [php, *shlex.split(os.environ.get("PRAXO_PHP_ARGS", ""))]
        composer_command = [*php_command, composer] if composer.endswith(".phar") else [composer]
        self.assertFalse(self.root.is_relative_to(package.ROOT))
        package.stage(self.output, self.files)
        consumer = self.root / "consumer"
        consumer.mkdir()
        metadata = {
            "name": "praxo-test/isolated-consumer",
            "require": {"axisvela/praxo-core": self.version},
            "repositories": [
                {"type": "path", "url": self.output.as_posix(), "options": {
                    "symlink": False, "versions": {"axisvela/praxo-core": self.version},
                }},
                {"packagist.org": False},
            ],
            "config": {"allow-plugins": False},
        }
        (consumer / "composer.json").write_text(json.dumps(metadata), encoding="utf-8")
        sdk = package.ROOT / "language/php"
        shutil.copyfile(sdk / "examples/consumer/starter.php", consumer / "starter.php")
        shutil.copyfile(sdk / "tests/package_consumer.php", consumer / "package_consumer.php")
        environment = os.environ.copy()
        environment["COMPOSER_HOME"] = str(self.root / "composer-home")
        environment["COMPOSER_CACHE_DIR"] = str(self.root / "composer-cache")
        environment.pop("COMPOSER", None)

        def run(command):
            return subprocess.run(command, cwd=consumer, env=environment, capture_output=True,
                                  text=True, stdin=subprocess.DEVNULL, timeout=90)

        result = run(composer_command + ["--working-dir=" + str(self.output), "validate", "--strict"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = run(composer_command + ["install", "--no-interaction", "--no-plugins", "--no-scripts"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        installed = consumer / "vendor/axisvela/praxo-core"
        self.assertFalse(installed.is_symlink())
        package.check(installed, self.files)
        shutil.rmtree(self.output)
        result = run(php_command + ["package_consumer.php"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("allow: recorded; effects=1", result.stdout)
        self.assertIn("deny: policy rejected; effects=0", result.stdout)
        self.assertIn("isolated installed package passed", result.stdout)
        (installed / "src/PluginProcessHost.php").unlink()
        result = run(php_command + ["package_consumer.php"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("PluginProcessHost.php", result.stdout + result.stderr)
        self.assertNotIn("isolated installed package passed", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
