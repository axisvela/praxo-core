import json
from pathlib import Path
import tempfile
import unittest

import check_registry_pages as check


class RegistryPageTests(unittest.TestCase):
    def build(self, go="v2.7.0", python="0.3.2", typescript="0.2.2", java="0.4.1"):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        (root / "language").mkdir()
        (root / "docs/languages").mkdir(parents=True)
        metadata = {
            "Go": {"published_version": "v2.7.0"},
            "Python": {"published_version": "0.3.2"},
            "TypeScript": {"published_version": "0.2.2"},
            "Java": {"published_version": "0.4.1"},
        }
        (root / "language/registry-metadata.json").write_text(
            json.dumps(metadata), encoding="utf-8"
        )
        rows = [
            "| Language | Page | Published version | State | Action |",
            "| --- | --- | --- | --- | --- |",
            f"| Go | [pkg](https://pkg.go.dev/x) | `{go}` | ok | none |",
            f"| Python | [PyPI](https://pypi.org/x) | `{python}` | ok | none |",
            f"| TypeScript | [npm](https://npmjs.com/x) | `{typescript}` | ok | none |",
            f"| Java | [Maven](https://repo1.maven.org/x) | `{java}` | ok | none |",
        ]
        (root / "docs/languages/registry-pages.md").write_text(
            "\n".join(rows) + "\n", encoding="utf-8"
        )
        self.root = root

    def tearDown(self):
        self.directory.cleanup()

    def errors(self):
        return check.validate(self.root)

    def test_valid_pages_pass(self):
        self.build()
        self.assertEqual(self.errors(), [])

    def test_page_version_mismatch_is_rejected(self):
        self.build()
        path = self.root / "docs/languages/registry-pages.md"
        path.write_text(path.read_text().replace("`0.3.2`", "`0.3.1`"), encoding="utf-8")
        self.assertTrue(any("Python" in error for error in self.errors()))

    def test_missing_pilot_row_is_rejected(self):
        self.build()
        path = self.root / "docs/languages/registry-pages.md"
        lines = [line for line in path.read_text().splitlines() if "| Java |" not in line]
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        self.assertTrue(any("Java" in error for error in self.errors()))


if __name__ == "__main__":
    unittest.main()
