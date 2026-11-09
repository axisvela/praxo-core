import json
from pathlib import Path
import tempfile
import unittest

import check_registry_state as check


class RegistryStateTests(unittest.TestCase):
    def build(self, go_source="v2.7.0", go_published="v2.7.0", python="0.3.2", status_python=None):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        (root / "language").mkdir()
        (root / "docs/languages").mkdir(parents=True)
        (root / "VERSION").write_text("2.7.0\n", encoding="utf-8")
        metadata = {
            "Go": {"source_version": go_source, "published_version": go_published},
            "Python": {"source_version": python, "published_version": python},
            "TypeScript": {"published_version": "0.2.2"},
            "Java": {"published_version": "0.4.1"},
            "Rust": {"published_version": "0.3.0"},
            "C#": {"published_version": "0.3.0"},
            "Elixir": {"published_version": "0.4.0"},
            "Erlang": {"published_version": "0.4.0"},
            "Ruby": {"published_version": "0.4.1"},
            "Lua": {"published_version": "0.4.0-1"},
            "PHP": {"published_version": "0.4.0"},
        }
        (root / "language/registry-metadata.json").write_text(
            json.dumps(metadata), encoding="utf-8"
        )
        status_python = status_python or python
        rows = [
            "| Language | Registry | Version | Address | Status |",
            "| --- | --- | --- | --- | --- |",
            f"| Go | proxy | `{go_published}` | x | published |",
            f"| Python | PyPI | `{status_python}` | x | published |",
            "| TypeScript | npm | `0.2.2` | x | published |",
            "| Java | Maven | `0.4.1` | x | published |",
            "| Rust | crates | `0.3.0` | x | published |",
            "| C# | NuGet | `0.3.0` | x | published |",
            "| Elixir | Hex | `0.4.0` | x | published |",
            "| Erlang | Hex | `0.4.0` | x | published |",
            "| Ruby | RubyGems | `0.4.1` | x | published |",
            "| Lua | LuaRocks | `0.4.0-1` | x | published |",
            "| PHP | Packagist | `0.4.0` | x | published |",
        ]
        (root / "docs/languages/registry-status.md").write_text(
            "\n".join(rows) + "\n", encoding="utf-8"
        )
        self.root = root

    def tearDown(self):
        self.directory.cleanup()

    def errors(self):
        return check.validate(self.root)

    def test_valid_state_passes(self):
        self.build()
        self.assertEqual(self.errors(), [])

    def test_status_version_mismatch_is_rejected(self):
        self.build(status_python="0.3.1")
        self.assertTrue(any("Python" in error for error in self.errors()))

    def test_missing_status_row_is_rejected(self):
        self.build()
        path = self.root / "docs/languages/registry-status.md"
        lines = [line for line in path.read_text().splitlines() if "| Rust |" not in line]
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        self.assertTrue(any("Rust" in error for error in self.errors()))

    def test_go_source_must_match_version(self):
        self.build(go_source="v2.6.0")
        self.assertTrue(any("VERSION" in error for error in self.errors()))


if __name__ == "__main__":
    unittest.main()
