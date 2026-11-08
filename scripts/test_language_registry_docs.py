import importlib.util
import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "sync_language_registry_docs", ROOT / "scripts/sync_language_registry_docs.py"
)
SYNC = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(SYNC)


class LanguageRegistryDocsTests(unittest.TestCase):
    def test_every_language_directory_is_indexed(self):
        language_dirs = sorted(
            path.name for path in (ROOT / "language").iterdir() if path.is_dir()
        )
        indexed = sorted(
            Path(entry["dir"]).name
            for entry in SYNC.LANGUAGES
            if entry["dir"] != "."
        )
        self.assertEqual(language_dirs, indexed)
        index = (ROOT / "language/REGISTRY-INDEX.md").read_text(encoding="utf-8")
        for entry in SYNC.LANGUAGES:
            if entry["dir"] == ".":
                continue
            relative = Path(entry["dir"]).relative_to("language").as_posix()
            with self.subTest(language=entry["name"]):
                self.assertIn(f"{relative}/REGISTRY.md", index)
                self.assertIn(f"{relative}/llms.txt", index)
                self.assertIn(f"{relative}/llms.md", index)

    def test_entries_exist_and_cover_package_metadata(self):
        for entry in SYNC.LANGUAGES:
            directory = ROOT / entry["dir"]
            with self.subTest(language=entry["name"]):
                registry = directory / "REGISTRY.md"
                llms_md = directory / "llms.md"
                llms_txt = directory / "llms.txt"
                readme = directory / "README.md"
                for path in (registry, llms_md, readme):
                    self.assertTrue(path.is_file(), path)
                if entry["dir"] == ".":
                    self.assertTrue((ROOT / "llms.txt").is_file())
                else:
                    self.assertTrue(llms_txt.is_file(), llms_txt)
                registry_text = registry.read_text(encoding="utf-8")
                self.assertIn("## Package", registry_text)
                self.assertIn("## Boundaries", registry_text)
                self.assertIn(entry["package"], registry_text)
                self.assertIn(entry["version"], registry_text)
                self.assertIn(entry["install"], registry_text)
                self.assertIn(SYNC.BLOCK_START, readme.read_text(encoding="utf-8"))
                self.assertTrue(llms_md.read_text(encoding="utf-8").startswith("# PRAXO-CORE"))
                if entry["dir"] != ".":
                    self.assertTrue(
                        llms_txt.read_text(encoding="utf-8").startswith("# PRAXO-CORE")
                    )

    def test_root_llms_points_to_language_entries(self):
        text = (ROOT / "llms.txt").read_text(encoding="utf-8")
        self.assertIn("language/REGISTRY-INDEX.md", text)
        for language in ("python", "typescript", "java", "rust", "csharp"):
            self.assertIn(f"language/{language}/llms.txt", text)

    def test_packaging_manifests_include_entries(self):
        checks = {
            "language/typescript/package.json": ('"llms.txt"', '"llms.md"', '"REGISTRY.md"'),
            "language/python/MANIFEST.in": ("llms.txt", "llms.md", "REGISTRY.md"),
            "language/rust/Cargo.toml": ('llms.txt', 'llms.md', 'REGISTRY.md'),
            "language/csharp/Praxo.Core/Praxo.Core.csproj": (
                "../llms.txt", "../llms.md", "../REGISTRY.md"
            ),
            "language/ruby/praxo-core.gemspec": ("llms.txt", "llms.md", "REGISTRY.md"),
            "language/elixir/mix.exs": ("llms.txt", "llms.md", "REGISTRY.md"),
            "language/perl/MANIFEST": ("llms.txt", "llms.md", "REGISTRY.md"),
            "language/haskell/praxo-core.cabal": ("llms.txt", "llms.md", "REGISTRY.md"),
            "language/java/pom.xml": ("llms.txt", "llms.md", "REGISTRY.md"),
        }
        for relative, terms in checks.items():
            text = (ROOT / relative).read_text(encoding="utf-8")
            for term in terms:
                with self.subTest(file=relative, term=term):
                    self.assertIn(term, text)


if __name__ == "__main__":
    unittest.main()
