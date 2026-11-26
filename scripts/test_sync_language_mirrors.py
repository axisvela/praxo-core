import fnmatch
import re
import tempfile
import unittest
from pathlib import Path

import sync_language_mirrors as sync
from mirror_readme import _published


class MirrorSyncTests(unittest.TestCase):
    def test_mirror_keys_cover_newer_repositories(self):
        self.assertEqual(len(sync.MIRROR_KEYS), 22)
        self.assertEqual(
            set(sync.MIRROR_KEYS),
            {
                "go",
                "python",
                "typescript",
                "java",
                "rust",
                "csharp",
                "r",
                "elixir",
                "erlang",
                "perl",
                "haskell",
                "dart",
                "zig",
                "c",
                "cpp",
                "fortran",
                "cobol",
                "powershell",
                "matlab",
                "octave",
                "delphi",
                "objc",
            },
        )

    def test_publication_sources_are_not_mirrored(self):
        for key in ("ruby", "php", "lua", "swift", "julia", "v", "ocaml", "nim", "d"):
            self.assertNotIn(key, sync.MIRROR_KEYS)

    def test_entries_come_from_registry_metadata(self):
        entries = {entry["key"]: entry for entry in sync.mirror_entries()}
        self.assertEqual(entries["python"]["package"], "praxo-core")
        self.assertEqual(entries["csharp"]["name"], "C#")
        self.assertIn("language/matlab-octave-core", entries["octave"]["source_dirs"])
        self.assertIn("language/matlab-octave-core", entries["matlab"]["source_dirs"])

    def test_go_mirror_uses_root_sources(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["go"]
        self.assertEqual(entry["dir"], ".")
        self.assertIn("pkg", entry["source_dirs"])
        self.assertIn("go.mod", entry["source_files"])
        self.assertEqual(entry["readme_source"], "docs/languages/go/index.md")
        self.assertIn("language/go/examples", entry["examples_dirs"])

    def test_readme_and_gitignore_are_stable(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["python"]
        readme = sync.mirror_readme(entry)
        self.assertIn("PRAXO-CORE for Python", readme)
        self.assertIn("Canonical source:", readme)
        self.assertIn("language/python", readme)
        self.assertIn("praxo-core", readme)
        self.assertIn("## Highlights", readme)
        self.assertIn("## Quick start", readme)
        self.assertIn("## Community", readme)
        self.assertIn("https://x.com/axisvela", readme)
        self.assertIn("https://weibo.com/u/1936025761", readme)
        self.assertIn("https://www.linkedin.com/company/axisvela/", readme)
        self.assertIn("https://www.facebook.com/profile.php?id=61596905732406", readme)
        self.assertIn("https://www.youtube.com/@axisvela", readme)
        self.assertIn("https://discord.com/channels/1575163993767809064/1575164343148875977", readme)
        self.assertIn("https://github.com/axisvela/praxo-core/discussions", readme)
        self.assertIn("https://github.com/axisvela/praxo-core/issues", readme)
        self.assertIn("https://axisvela.github.io/praxo-core/", readme)
        self.assertIn("https://axisvela.architect.pub", readme)
        self.assertIn("build/", sync.mirror_gitignore())

    def test_readme_links_examples_when_present(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["python"]
        readme = sync.mirror_readme(entry, has_examples=True)
        self.assertIn("language/python/examples", readme)

    def test_readme_uses_language_intro_and_example_catalog(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["rust"]
        readme = sync.mirror_readme(entry, has_examples=True)
        self.assertIn("native Rust Core", readme)
        self.assertIn("provider-fallback", readme)
        self.assertIn("## What's included", readme)
        self.assertIn("## Examples", readme)
        self.assertIn("## Scenario Tutorials", readme)

    def test_readme_lists_reference_applications(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["java"]
        readme = sync.mirror_readme(entry, has_examples=True)
        self.assertIn("## Reference Applications", readme)
        self.assertIn("language/java/application", readme)

    def test_go_mirror_readme_uses_root_layout(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["go"]
        readme = sync.mirror_readme(entry, has_examples=True)
        self.assertIn("PRAXO-CORE for Go", readme)
        version = (sync.ROOT / "VERSION").read_text(encoding="utf-8").strip()
        self.assertIn(f"go get github.com/axisvela/praxo-core/v2@v{version}", readme)
        self.assertIn("language/go/examples/consumer-go", readme)
        self.assertIn("language/go/examples/live-model", readme)
        self.assertIn("language/go/Tutorial", readme)
        self.assertNotIn("](examples)", readme)
        self.assertNotIn("Complete AI-native reference applications", readme)
        self.assertIn("Canonical source tag", readme)
        self.assertIn(f"https://github.com/axisvela/praxo-core/tree/{entry['tag']}", readme)
        self.assertIn("not necessarily present in this mirror", readme)
        self.assertIn("does not publish mirror tags or registry packages", readme)

    def test_readme_resolves_intro_and_catalog_links_at_original_sources(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["dart"]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sources = {
                "language/dart/README.md": (
                    "# Dart\n\nSee [contract](../../spec/README.md).\n\n"
                    "- Publishing setup: [PUBLISHING.md](PUBLISHING.md)\n"
                    "- [Site](https://example.com) and [mail](mailto:hello@example.com)\n"
                    "## Usage\n"
                ),
                "language/dart/examples/demo/README.md": (
                    "# Demo\n\nSee [setup](../../SETUP.md#build) and "
                    "[source](main.dart).\n"
                ),
                "language/dart/Tutorial/README.md": (
                    "# Tutorials\n\nSee [ecosystem](../ecosystem/README.md).\n"
                ),
                "language/dart/application/demo/README.md": (
                    "# Application\n\nSee [plan](../README.md) and [scope](#scope). "
                    + "Implementation in progress. " * 10 + "\n"
                ),
            }
            for relative, text in sources.items():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            readme = sync.mirror_readme(entry, has_examples=True, root=root)
            base = "https://github.com/axisvela/praxo-core/blob/main/"
            for target in (
                "spec/README.md", "language/dart/PUBLISHING.md",
                "language/dart/SETUP.md#build", "language/dart/examples/demo/main.dart",
                "language/dart/ecosystem/README.md", "language/dart/application/README.md",
                "language/dart/application/demo/README.md#scope",
            ):
                self.assertIn(f"]({base}{target})", readme)
            self.assertIn("](https://example.com)", readme)
            self.assertIn("](mailto:hello@example.com)", readme)
            self.assertIn("See each README for implementation scope and validation status.", readme)

    def test_go_catalog_links_resolve_to_canonical_ecosystem(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["go"]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "language/go/Tutorial/README.md"
            path.parent.mkdir(parents=True)
            path.write_text("# Tutorials\n\nSee [ecosystem](../ecosystem/README.md).\n", encoding="utf-8")
            readme = sync.mirror_readme(entry, root=root)
            self.assertIn(
                "](https://github.com/axisvela/praxo-core/blob/main/language/go/ecosystem/README.md)",
                readme,
            )

    def test_publication_requires_version_and_not_just_pending_registry(self):
        cases = [
            ("", "published", False),
            ("  ", "published", False),
            ("1.0.0", "source-only", False),
            ("1.0.0", "shared implementation", False),
            ("1.0.0", "pending registry merge", False),
            ("1.0.0", "split repository; registry crawler pending", False),
            ("1.0.0", "published; next upload pending", True),
            ("1.0.0", "release tarball published; package index PR pending", True),
        ]
        for version, status, expected in cases:
            with self.subTest(version=version, status=status):
                self.assertEqual(_published({"published_version": version, "status": status}), expected)

    def test_unavailable_package_readme_does_not_claim_source_only(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["dart"]
        for version, status in (("", "published"), ("1.0.0", "pending registry merge")):
            with self.subTest(version=version, status=status):
                readme = sync.mirror_readme(dict(entry, published_version=version, status=status))
                self.assertIn("| Published version | not published |", readme)
                self.assertNotIn("Install the published package:", readme)
                self.assertIn("No published package is available.", readme)

    def test_pending_registry_archive_readme_uses_download_not_registry_install(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["octave"]
        entry = dict(entry, published_version="1.0.0", install="pkg install -forge praxo-core",
                     status="release tarball published; package index PR pending",
                     url="https://github.com/axisvela/praxo-core/releases/download/octave/v1.0.0/core.tar.gz")
        readme = sync.mirror_readme(entry)
        self.assertIn("| Archive version | `1.0.0` |", readme)
        self.assertIn("| Download | [Release assets]", readme)
        self.assertIn("The registry listing is still pending", readme)
        self.assertNotIn("Install the published package:", readme)
        self.assertNotIn("pkg install -forge praxo-core", readme)

    def test_workflow_triggers_cover_all_mirror_inputs(self):
        workflow = (sync.ROOT / ".github/workflows/language-mirrors.yml").read_text(encoding="utf-8")
        for event in ("push", "pull_request"):
            block = re.split(r"\n  \w", workflow.split(f"  {event}:\n", 1)[1], maxsplit=1)[0]
            patterns = [line.strip()[3:-1] for line in block.splitlines() if line.strip().startswith('- "')]
            for entry in sync.mirror_entries():
                inputs = [f"{source}/probe" for source in entry["source_dirs"]]
                inputs.extend(entry.get("source_files", []))
                inputs.extend([entry["readme_source"], "spec/SPEC_VERSION", "LICENSE"])
                for source in inputs:
                    with self.subTest(event=event, source=source):
                        self.assertTrue(any(fnmatch.fnmatchcase(source, pattern) for pattern in patterns))

    def test_build_mirror_copies_sources_and_ignores_artifacts(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["python"]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "language/python/praxo").mkdir(parents=True)
            (root / "language/python/praxo/__init__.py").write_text("x = 1\n", encoding="utf-8")
            (root / "language/python/build").mkdir()
            (root / "language/python/build/artifact.txt").write_text("no\n", encoding="utf-8")
            (root / "language/python/__pycache__").mkdir()
            (root / "language/python/__pycache__/x.pyc").write_bytes(b"no")
            (root / "spec").mkdir()
            (root / "spec/SPEC_VERSION").write_text("0.2.0\n", encoding="utf-8")
            (root / "LICENSE").write_text("MIT\n", encoding="utf-8")

            target = root / "mirror"
            sync.build_mirror(entry, target, root)
            self.assertTrue((target / "language/python/praxo/__init__.py").is_file())
            self.assertTrue((target / "spec/SPEC_VERSION").is_file())
            self.assertTrue((target / "LICENSE").is_file())
            self.assertTrue((target / "README.md").is_file())
            self.assertFalse((target / "language/python/build").exists())
            self.assertFalse((target / "language/python/__pycache__").exists())

    def test_build_mirror_keeps_git_directory_when_not_cleaning(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["python"]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "language/python").mkdir(parents=True)
            (root / "language/python/README.md").write_text("python\n", encoding="utf-8")
            (root / "spec").mkdir()
            (root / "spec/SPEC_VERSION").write_text("0.2.0\n", encoding="utf-8")
            (root / "LICENSE").write_text("MIT\n", encoding="utf-8")
            target = root / "mirror"
            (target / ".git").mkdir(parents=True)
            (target / ".git/keep").write_text("keep\n", encoding="utf-8")

            sync.build_mirror(entry, target, root, clean=False)
            self.assertTrue((target / ".git/keep").is_file())
            self.assertTrue((target / "language/python/README.md").is_file())

    def test_build_mirror_ignores_local_lockfiles(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["dart"]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "language/dart").mkdir(parents=True)
            (root / "language/dart/pubspec.yaml").write_text("name: praxo\n", encoding="utf-8")
            (root / "language/dart/pubspec.lock").write_text("local lock\n", encoding="utf-8")
            (root / "spec").mkdir()
            (root / "spec/SPEC_VERSION").write_text("0.2.0\n", encoding="utf-8")
            (root / "LICENSE").write_text("MIT\n", encoding="utf-8")

            target = root / "mirror"
            sync.build_mirror(entry, target, root)
            self.assertTrue((target / "language/dart/pubspec.yaml").is_file())
            self.assertFalse((target / "language/dart/pubspec.lock").exists())

    def test_build_mirror_includes_shared_matlab_octave_core(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["octave"]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in ("language/octave", "language/matlab-octave-core/praxo", "spec"):
                (root / relative).mkdir(parents=True)
            (root / "language/octave/README.md").write_text("octave\n", encoding="utf-8")
            (root / "language/matlab-octave-core/praxo/core.m").write_text("% core\n", encoding="utf-8")
            (root / "spec/SPEC_VERSION").write_text("0.2.0\n", encoding="utf-8")
            (root / "LICENSE").write_text("MIT\n", encoding="utf-8")

            target = root / "mirror"
            sync.build_mirror(entry, target, root)
            self.assertTrue((target / "language/matlab-octave-core/praxo/core.m").is_file())

    def test_parse_only_filters_and_rejects_unknown(self):
        self.assertEqual(sync.parse_only("python,java"), ["python", "java"])
        self.assertIsNone(sync.parse_only(None))
        with self.assertRaises(SystemExit):
            sync.parse_only("python,unknown")


if __name__ == "__main__":
    unittest.main()
