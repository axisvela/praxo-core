import tempfile
import unittest
from pathlib import Path

import sync_language_mirrors as sync


class MirrorSyncTests(unittest.TestCase):
    def test_mirror_keys_cover_newer_repositories(self):
        self.assertEqual(len(sync.MIRROR_KEYS), 21)
        self.assertEqual(
            set(sync.MIRROR_KEYS),
            {
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

    def test_readme_and_gitignore_are_stable(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["python"]
        readme = sync.mirror_readme(entry)
        self.assertIn("PRAXO-CORE for Python", readme)
        self.assertIn("Canonical source:", readme)
        self.assertIn("language/python", readme)
        self.assertIn("praxo-core", readme)
        self.assertNotIn("Examples:", readme)
        self.assertIn("build/", sync.mirror_gitignore())

    def test_readme_links_examples_when_present(self):
        entry = {entry["key"]: entry for entry in sync.mirror_entries()}["python"]
        readme = sync.mirror_readme(entry, has_examples=True)
        self.assertIn("language/python/examples", readme)

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
