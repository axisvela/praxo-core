import importlib.util
import io
import json
import re
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch


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
    def test_audited_published_versions(self):
        expected = {
            "Go": "v2.11.1", "Python": "0.11.0", "TypeScript": "0.10.0",
            "Java": "0.12.0", "Rust": "0.11.1", "C#": "0.11.0",
            "R": "0.12.0", "Ruby": "0.10.0", "PHP": "0.10.0",
            "Dart": "0.8.2", "Elixir": "0.11.1", "Erlang": "0.10.1",
            "Lua": "0.9.1-1", "Perl": "0.8.1", "Haskell": "0.9.0",
            "D": "0.8.0", "Swift": "0.7.2", "MATLAB": "0.9.1",
            "GNU Octave": "0.9.0", "Delphi / Free Pascal": "0.9.0",
        }
        for entry in SYNC.LANGUAGES:
            if entry["name"] not in expected:
                continue
            with self.subTest(language=entry["name"]):
                self.assertTrue(SYNC.published_available(entry))
                self.assertEqual(entry["published_version"], expected[entry["name"]])
        matlab = next(entry for entry in SYNC.LANGUAGES if entry["name"] == "MATLAB")
        self.assertEqual(matlab["source_version"], "0.9.0")

    def test_publication_requires_positive_evidence(self):
        entry = {"status": "published", "published_version": "0.1.0", "url": "https://example.com/package"}
        self.assertTrue(SYNC.published_available(entry))
        for change in (
            {"published_version": ""}, {"url": ""}, {"status": "prepared"},
            {"status": "pending registry merge"}, {"status": "not published"},
            {"status": "source-only"}, {"status": "shared implementation"},
            {"status": "published; source-only"},
        ):
            with self.subTest(change=change):
                self.assertFalse(SYNC.published_available(entry | change))
                self.assertEqual(SYNC.published_install_label(entry | change), "not published")
                self.assertEqual(SYNC.published_version_label(entry | change), "not published")

    def test_unpublished_entries_have_no_published_claim(self):
        for entry in SYNC.LANGUAGES:
            if SYNC.published_available(entry):
                continue
            with self.subTest(language=entry["name"]):
                self.assertEqual(entry["published_version"], "")
                self.assertEqual(entry["install"], "")
                self.assertTrue(entry["source_install"])
                directory = ROOT / entry["dir"]
                registry = SYNC.render_registry(entry, directory)
                self.assertIn("| Published registry version | not published |", registry)
                self.assertIn("| Install (published) | not published |", registry)
                for markdown in (False, True):
                    text = SYNC.render_llms(entry, directory, markdown)
                    self.assertIn("- published_version: not published", text)
                    self.assertIn("- install_published: not published", text)
                if entry["tier"] != "Shared":
                    row = next(row for row in SYNC.root_language_rows() if row[0] == entry["name"])
                    self.assertEqual(row[3], "not published")

    def test_pending_entries_use_checkout_paths(self):
        for name in ("OCaml", "Julia", "V"):
            entry = next(entry for entry in SYNC.LANGUAGES if entry["name"] == name)
            with self.subTest(language=name):
                self.assertIn("pending", entry["status"])
                self.assertIn(entry["dir"], entry["source_install"])
                self.assertFalse(SYNC.published_available(entry))
        ocaml = next(entry for entry in SYNC.LANGUAGES if entry["name"] == "OCaml")
        self.assertIn("replacement submission pending", ocaml["status"])

    def test_readme_install_commands_match_current_registry(self):
        for entry in SYNC.LANGUAGES:
            if not SYNC.published_available(entry) or entry["name"] in {
                "Go", "PowerShell", "MATLAB", "Delphi / Free Pascal",
            }:
                continue
            with self.subTest(language=entry["name"]):
                text = (ROOT / entry["dir"] / "README.md").read_text(encoding="utf-8")
                self.assertIn(entry["install"], text)
                for command in re.findall(r"```[^\n]*\n(.*?)```", text, re.DOTALL):
                    for line in command.splitlines():
                        prefix = " ".join(entry["install"].split()[:2]) + " "
                        if line.startswith(prefix) and entry["package"] in line:
                            self.assertIn(entry["install"], line)

    def test_release_archive_installation_is_not_index_publication(self):
        octave = next(entry for entry in SYNC.LANGUAGES if entry["name"] == "GNU Octave")
        self.assertEqual(octave["install"], "pkg install " + octave["url"])
        self.assertNotIn("-forge", octave["install"])
        delphi = next(entry for entry in SYNC.LANGUAGES if entry["name"] == "Delphi / Free Pascal")
        self.assertIn("GitHub", delphi["registry"])
        self.assertIn("OPM listing unverified", delphi["status"])
        self.assertIn(delphi["url"], delphi["install"])

    def test_corrected_example_links(self):
        rust = (ROOT / "language/rust/README.md").read_text(encoding="utf-8")
        self.assertNotIn("language/go/examples", rust)
        self.assertNotIn("## Runnable Examples", rust)
        typescript = (ROOT / "language/typescript/README.md").read_text(encoding="utf-8")
        self.assertNotIn("https://github.com/axisvela/praxo-core/tree/main/examples", typescript)

    def test_check_rejects_stale_manifest(self):
        with TemporaryDirectory() as temporary:
            manifest = Path(temporary) / "registry-metadata.json"
            manifest.write_text("{}", encoding="utf-8")
            with (
                patch.object(SYNC, "MANIFEST", manifest),
                patch.object(SYNC, "ROOT", Path(temporary)),
                patch.object(SYNC, "LANGUAGES", []),
                patch.object(SYNC, "manifest_data", return_value={"expected": {}}),
                patch("sys.argv", ["sync_language_registry_docs.py", "--check"]),
                patch("sys.stdout", new_callable=io.StringIO) as output,
            ):
                self.assertEqual(SYNC.main(), 1)
                self.assertIn("stale registry metadata", output.getvalue())
            manifest.write_text('{"expected": {}}', encoding="utf-8")
            with (
                patch.object(SYNC, "MANIFEST", manifest),
                patch.object(SYNC, "LANGUAGES", []),
                patch.object(SYNC, "manifest_data", return_value={"expected": {}}),
                patch("sys.argv", ["sync_language_registry_docs.py", "--check"]),
            ):
                self.assertEqual(SYNC.main(), 0)

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
            self.assertIn("https://www.linkedin.com/company/axisvela/", text)
            self.assertIn("https://www.facebook.com/profile.php?id=61596905732406", text)
            self.assertIn("https://www.youtube.com/@axisvela", text)
            self.assertIn("https://discord.com/channels/1575163993767809064/1575164343148875977", text)
            self.assertIn("https://github.com/axisvela/praxo-core/discussions", text)
            self.assertIn("https://github.com/axisvela/praxo-core/issues", text)
            self.assertIn("https://axisvela.github.io/praxo-core/", text)
            self.assertIn("https://axisvela.architect.pub", text)
        root_registry = (ROOT / "REGISTRY.md").read_text(encoding="utf-8")
        root_llms = (ROOT / "llms.md").read_text(encoding="utf-8")
        for text in (root_registry, root_llms):
            self.assertIn("https://x.com/axisvela", text)
            self.assertIn("https://weibo.com/u/1936025761", text)
            self.assertIn("https://www.linkedin.com/company/axisvela/", text)
            self.assertIn("https://www.facebook.com/profile.php?id=61596905732406", text)
            self.assertIn("https://www.youtube.com/@axisvela", text)
            self.assertIn("https://discord.com/channels/1575163993767809064/1575164343148875977", text)
            self.assertIn("https://github.com/axisvela/praxo-core/discussions", text)
            self.assertIn("https://github.com/axisvela/praxo-core/issues", text)
            self.assertIn("https://axisvela.github.io/praxo-core/", text)
            self.assertIn("https://axisvela.architect.pub", text)

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
