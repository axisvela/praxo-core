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

SAMPLE_ONLY = {
    "clojure",
    "fsharp",
    "groovy",
    "javascript",
    "kotlin",
    "opencl",
    "scala",
}
NON_REGISTRY = SAMPLE_ONLY | {"go"}


class LanguageRegistryDocsTests(unittest.TestCase):
    def test_every_registry_directory_is_indexed(self):
        language_dirs = sorted(
            path.name
            for path in (ROOT / "language").iterdir()
            if path.is_dir() and path.name not in NON_REGISTRY
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

    def test_example_links_match_example_directories(self):
        index = (ROOT / "language/REGISTRY-INDEX.md").read_text(encoding="utf-8")
        for entry in SYNC.LANGUAGES:
            if entry["dir"] == ".":
                continue
            relative = Path(entry["dir"]).relative_to("language").as_posix()
            directory = ROOT / entry["dir"]
            with self.subTest(language=entry["name"]):
                if (directory / "examples").is_dir():
                    self.assertIn(f"[examples]({relative}/examples/)", index)
                elif entry["name"] == "GNU Octave":
                    self.assertIn("[shared examples](matlab/examples/)", index)

    def test_sample_only_directories_are_indexed(self):
        index = (ROOT / "language/REGISTRY-INDEX.md").read_text(encoding="utf-8")
        for name in SAMPLE_ONLY:
            with self.subTest(language=name):
                self.assertIn(f"[examples]({name}/examples/)", index)

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
                if entry["dir"] == ".":
                    self.assertIn("## Languages", registry_text)
                    self.assertIn("## Boundaries", registry_text)
                    self.assertIn(entry["package"], registry_text)
                    self.assertIn(entry["published_version"], registry_text)
                else:
                    self.assertIn("## Package", registry_text)
                    self.assertIn("## Boundaries", registry_text)
                    self.assertIn(entry["package"], registry_text)
                    self.assertIn(entry["source_version"], registry_text)
                    if SYNC.published_available(entry):
                        self.assertIn(entry["published_version"], registry_text)
                        self.assertIn(entry["install"], registry_text)
                    self.assertIn(entry["source_install"], registry_text)
                readme_text = readme.read_text(encoding="utf-8")
                self.assertIn(SYNC.BLOCK_START, readme_text)
                block = readme_text.split(SYNC.BLOCK_START, 1)[1].split("\n## ", 1)[0]
                base = "https://github.com/axisvela/praxo-core/blob/main"
                prefix = base if entry["dir"] == "." else f"{base}/{Path(entry['dir']).as_posix()}"
                for name in ("REGISTRY.md", "llms.txt", "llms.md"):
                    self.assertIn(f"]({prefix}/{name})", block)
                self.assertIn(
                    "](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)",
                    block,
                )
                self.assertNotIn("](REGISTRY.md)", block)
                self.assertTrue(llms_md.read_text(encoding="utf-8").startswith("# PRAXO-CORE"))
                if entry["dir"] != ".":
                    self.assertTrue(
                        llms_txt.read_text(encoding="utf-8").startswith("# PRAXO-CORE")
                    )

    def test_community_links_are_present(self):
        for entry in SYNC.LANGUAGES:
            directory = ROOT / entry["dir"]
            with self.subTest(language=entry["name"]):
                for name in ("REGISTRY.md", "llms.md", "README.md"):
                    text = (directory / name).read_text(encoding="utf-8")
                    self.assertIn("https://x.com/axisvela", text)
                    self.assertIn("https://weibo.com/u/1936025761", text)
        root_registry = (ROOT / "REGISTRY.md").read_text(encoding="utf-8")
        root_llms = (ROOT / "llms.md").read_text(encoding="utf-8")
        for text in (root_registry, root_llms):
            self.assertIn("https://x.com/axisvela", text)
            self.assertIn("https://weibo.com/u/1936025761", text)

    def test_machine_readable_manifest_matches_entries(self):
        manifest = json.loads((ROOT / "language/registry-metadata.json").read_text(encoding="utf-8"))
        for entry in SYNC.LANGUAGES:
            with self.subTest(language=entry["name"]):
                data = manifest[entry["name"]]
                self.assertEqual(data["source_version"], entry["source_version"])
                self.assertEqual(data["published_version"], entry["published_version"])
                self.assertEqual(data["install"], entry["install"])
                self.assertEqual(data["source_install"], entry["source_install"])

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
