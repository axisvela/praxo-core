import contextlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import build_ocaml_package as package


class OcamlPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.version, cls.files = package.payload()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / "package"

    def stage(self, archive=None, sync_split=False):
        with patch.object(package, "payload", return_value=(self.version, self.files)):
            with contextlib.redirect_stdout(io.StringIO()) as output:
                result = package.stage(self.output, archive, sync_split=sync_split)
        return result, output.getvalue()

    def source_fixture(self):
        root = self.root / "canonical"
        provenance = json.loads(self.files["PROVENANCE.json"])
        for name in provenance["inputs"]:
            destination = root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(package.ROOT / name, destination)
        return root

    def fixture_payload(self, root):
        git = package.git
        with patch.object(package, "git", side_effect=lambda _, *args, **kw: git(package.ROOT, *args, **kw)):
            return package.payload(root)

    def test_full_payload_exact_bytes_and_modes(self):
        self.stage()
        self.assertEqual(self.version, "0.11.0")
        expected = set(self.files)
        actual = {p.relative_to(self.output).as_posix() for p in self.output.rglob("*") if p.is_file()}
        self.assertEqual(expected, actual)
        for name, data in self.files.items():
            target = self.output / name
            self.assertEqual(target.read_bytes(), data, name)
            if os.name != "nt":
                self.assertEqual(target.stat().st_mode & 0o777, 0o644, name)
        sdk = package.ROOT / "language/ocaml"
        for name in ["praxo_core.ml", "praxo_core.mli"] + [module + ".ml" for module in package.SRC_MODULES]:
            self.assertEqual((self.output / "src" / name).read_bytes(), (sdk / "src" / name).read_bytes())
        for name in ("praxo_tests.ml", "praxo_adapter_tests.ml"):
            self.assertEqual((self.output / "tests" / name).read_bytes(), (sdk / "tests" / name).read_bytes())
        for name in ("LICENSE", "CHANGELOG.md", "VERSION"):
            self.assertEqual((self.output / name).read_bytes(), (sdk / name).read_bytes())
        vectors = package.ROOT / "spec/vectors"
        for source in vectors.rglob("*"):
            if source.is_file():
                self.assertEqual((self.output / "tests/spec/vectors" / source.relative_to(vectors)).read_bytes(), source.read_bytes())
        fixture = "tests/tests/fixtures/process_plugin.py"
        self.assertEqual(self.files[fixture], (sdk / "tests/fixtures/process_plugin.py").read_bytes())
        self.assertIn(f"api/{self.version}.txt", expected)
        self.assertFalse(any(name.endswith((".cmi", ".cmo", ".exe")) for name in expected))

    def test_dune_opam_and_readme_metadata(self):
        project = self.files["dune-project"].decode()
        self.assertEqual(project, f"(lang dune 3.0)\n(name praxo_core)\n(version {self.version})\n(generate_opam_files false)\n")
        library = self.files["src/dune"].decode()
        for field in ("(public_name praxo-core)", "(wrapped false)", "(modules praxo_core",
                      "(private_modules praxo_types", "(libraries unix)"):
            self.assertIn(field, library)
        tests = self.files["tests/dune"].decode()
        self.assertIn("(modules praxo_tests praxo_adapter_tests)", tests)
        self.assertIn("(modes byte)", tests)
        self.assertIn("(action (run %{test} spec))", tests)
        self.assertIn("(source_tree spec)", tests)
        self.assertIn("(source_tree tests)", tests)
        opam = self.files["praxo-core.opam"].decode()
        for text in ('license: "MIT"', '"ocaml" {>= "4.14"}', '"dune" {>= "3.0"}',
                     '["dune" "build" "-p" name "-j" jobs]',
                     '["dune" "runtest" "-p" name "-j" jobs] {with-test}',
                     '"conf-python-3" {with-test}', "hanhuiwen@axisvela.com"):
            self.assertIn(text, opam)
        self.assertNotIn('"unix"', opam)
        self.assertIn('dev-repo: "git+https://github.com/axisvela/praxo-core-ocaml.git"', opam)
        self.assertNotIn('dev-repo: "git+https://github.com/axisvela/praxo-core.git"', opam)
        readme = self.files["README.md"].decode()
        for text in (self.version, "dune build", "dune runtest", "opam install . --with-test",
                     "Standalone Dune/opam source package generated", "staging alone does not establish opam availability",
                     "HEAD identity", "canonical tag reference", "https://axisvela.github.io/", "/examples)", "/src/praxo_core.mli)"):
            self.assertIn(text, readme)
        self.assertNotIn("../../", readme)
        self.assertNotIn("not an official release", readme)

    def test_package_local_registry_and_llms_metadata(self):
        links = {
            f"{package.REPOSITORY}/tree/ocaml/v{self.version}",
            "https://github.com/axisvela/praxo-core-ocaml",
            "https://axisvela.github.io/praxo-core/languages/ocaml/",
            "https://axisvela.github.io/praxo-core/getting-started/coding-agents/",
            f"{package.REPOSITORY}/tree/main/language/ocaml/examples",
            f"{package.REPOSITORY}/blob/main/SECURITY.md",
        }
        for name in ("REGISTRY.md", "llms.md", "llms.txt"):
            text = self.files[name].decode()
            for expected in (f"Source version: `{self.version}` (from `VERSION`)",
                             "opam package: `praxo-core`", "NOT published; publication pending",
                             "Source availability is not registry publication", "Independent OCaml runtime",
                             "optional process plugin host", "HTTP transport is caller-owned",
                             "tests run in bytecode mode", "opam install . --with-test",
                             "source HEAD", "PROVENANCE.json", f"ocaml/v{self.version}"):
                self.assertIn(expected, text, name)
            self.assertEqual(set(re.findall(r"\]\(([^)]+)\)", text)), links, name)
            for forbidden in ("0.3", "opam install praxo-core", "published version", "plugin host unavailable",
                              "no process plugin host", "maintainer feedback resolved"):
                self.assertNotIn(forbidden, text.lower(), name)
        for name in ("README.md", "REGISTRY.md", "llms.md", "llms.txt"):
            text = self.files[name].decode()
            self.assertNotRegex(text, r"(?<![\w/])(?:\.{1,2}/)*language/ocaml/")
            for target in re.findall(r"\]\(([^)]+)\)", text):
                if target.startswith("https://"):
                    self.assertNotIn("/../", target)
                    if target.startswith(package.REPOSITORY + "/blob/main/"):
                        self.assertTrue((package.ROOT / target.split("/blob/main/", 1)[1]).is_file(), target)
                    elif target.startswith(package.REPOSITORY + "/tree/main/"):
                        self.assertTrue((package.ROOT / target.split("/tree/main/", 1)[1]).is_dir(), target)
                    elif target.startswith("https://axisvela.github.io/praxo-core/"):
                        page = target.removeprefix("https://axisvela.github.io/praxo-core/").rstrip("/")
                        page = package.ROOT / "docs" / page
                        self.assertTrue(page.with_suffix(".md").is_file() or (page / "index.md").is_file(), target)
                else:
                    self.assertIn(target, self.files, name)

    def test_metadata_does_not_copy_source_publication_claims(self):
        root = self.source_fixture()
        for name in ("REGISTRY.md", "llms.md", "llms.txt"):
            (root / "language/ocaml" / name).write_text("Published 0.3.0. No process plugin host.\n")
        _, files = self.fixture_payload(root)
        provenance = json.loads(files["PROVENANCE.json"])
        for name in ("REGISTRY.md", "llms.md", "llms.txt"):
            self.assertEqual(files[name], self.files[name])
            self.assertNotIn("language/ocaml/" + name, provenance["inputs"])

    def test_provenance_identifies_actual_inputs_not_tagged_content(self):
        root = self.source_fixture()
        changelog = root / "language/ocaml/CHANGELOG.md"
        changelog.write_bytes(changelog.read_bytes() + b"\nLocal changed changelog snapshot.\n")
        version, files = self.fixture_payload(root)
        provenance = json.loads(files["PROVENANCE.json"])
        self.assertEqual(provenance["canonical_tag_reference"], f"ocaml/v{version}")
        self.assertEqual(provenance["head_commit"], package.git(package.ROOT, "rev-parse", "HEAD"))
        record = provenance["inputs"]["language/ocaml/CHANGELOG.md"]
        self.assertFalse(record["matches_head"])
        self.assertEqual(record["worktree_sha256"], package.sha256(changelog.read_bytes()))
        self.assertIsNotNone(record["head_blob_oid"])
        self.assertIn("references only", provenance["identity_note"])
        manifest = json.loads(files[package.OWNER])
        self.assertEqual(set(manifest["files"]), set(files) - {package.OWNER})
        for name, digest in manifest["files"].items():
            self.assertEqual(digest, package.sha256(files[name]))

    def test_version_mismatch_rejected_before_writing(self):
        root = self.source_fixture()
        version = root / "language/ocaml/VERSION"
        version.write_bytes(b"0.11.1\n")
        with self.assertRaisesRegex(ValueError, "sdk_version"):
            package.stage(self.output, root=root)
        self.assertFalse(self.output.exists())
        version.write_bytes(b"0.11.0-rc1\n")
        with self.assertRaisesRegex(ValueError, "plain X.Y.Z"):
            package.stage(self.output, root=root)

    def test_rerun_preserves_unrelated_files_and_git(self):
        self.output.mkdir()
        (self.output / ".git").mkdir()
        sentinel = self.output / ".git/config"
        sentinel.write_bytes(b"untouched git metadata")
        unrelated = self.output / "local-notes.txt"
        unrelated.write_bytes(b"unowned")
        self.stage()
        self.stage()
        self.assertEqual(sentinel.read_bytes(), b"untouched git metadata")
        self.assertEqual(unrelated.read_bytes(), b"unowned")

    def test_unowned_collision_rejected_without_partial_writes(self):
        self.output.mkdir()
        sentinel = self.output / "README.md"
        sentinel.write_bytes(b"unowned readme")
        with self.assertRaisesRegex(ValueError, "unowned or edited"):
            self.stage()
        self.assertEqual(list(self.output.iterdir()), [sentinel])
        self.assertEqual(sentinel.read_bytes(), b"unowned readme")

    def test_edited_owned_file_rejected_without_partial_update(self):
        self.stage()
        target = self.output / "README.md"
        target.write_bytes(b"user edits")
        before = {p: p.read_bytes() for p in self.output.rglob("*") if p.is_file()}
        with self.assertRaisesRegex(ValueError, "unowned or edited"):
            self.stage()
        self.assertEqual(before, {p: p.read_bytes() for p in self.output.rglob("*") if p.is_file()})

    def test_owned_update_and_stale_manifest(self):
        self.stage()
        changed = dict(self.files)
        changed["README.md"] += b"\nUpdated generated readme.\n"
        manifest = json.loads(changed[package.OWNER])
        manifest["files"]["README.md"] = package.sha256(changed["README.md"])
        changed[package.OWNER] = package.json_bytes(manifest)
        with patch.object(package, "payload", return_value=(self.version, changed)):
            package.stage(self.output)
        self.assertEqual((self.output / "README.md").read_bytes(), changed["README.md"])
        del changed["README.md"]
        with patch.object(package, "payload", return_value=(self.version, changed)):
            with self.assertRaisesRegex(ValueError, "Stale"):
                package.stage(self.output)
        self.assertTrue((self.output / "README.md").exists())

    def test_symlink_output_rejected(self):
        elsewhere = self.root / "elsewhere"
        elsewhere.mkdir()
        try:
            self.output.symlink_to(elsewhere, target_is_directory=True)
        except OSError:
            self.skipTest("Symlink creation is not permitted")
        with self.assertRaisesRegex(ValueError, "linked path"):
            self.stage()
        self.assertEqual(list(elsewhere.iterdir()), [])

    def test_parent_file_and_git_output_rejected(self):
        self.output.mkdir()
        (self.output / "src").write_bytes(b"unrelated")
        with self.assertRaisesRegex(ValueError, "Parent is not a directory"):
            self.stage()
        self.assertEqual((self.output / "src").read_bytes(), b"unrelated")
        with self.assertRaisesRegex(ValueError, "outside .git"):
            package.stage(self.root / ".git/package")

    def test_hardlinked_owned_file_rejected(self):
        self.stage()
        owned = self.output / "README.md"
        elsewhere = self.root / "user-readme.md"
        try:
            os.link(owned, elsewhere)
        except OSError:
            self.skipTest("Hard link creation is not permitted")
        with self.assertRaisesRegex(ValueError, "hard-linked"):
            self.stage()
        self.assertEqual(elsewhere.read_bytes(), self.files["README.md"])

    def test_archive_is_deterministic_complete_and_normalized(self):
        archive = self.root / "package.tar.gz"
        _, printed = self.stage(archive)
        first = archive.read_bytes()
        self.assertIn(package.sha256(first), printed)
        os.utime(self.output / "src/praxo_core.ml", (1000000, 1000000))
        self.stage(archive)
        self.assertEqual(archive.read_bytes(), first)
        self.assertEqual(first, package.archive_bytes(self.version, self.files))
        with tarfile.open(fileobj=io.BytesIO(first), mode="r:gz") as tar:
            archived = {}
            for entry in tar.getmembers():
                self.assertEqual((entry.uid, entry.gid, entry.mtime, entry.uname, entry.gname), (0, 0, 0, "", ""))
                self.assertEqual(entry.mode, 0o755 if entry.isdir() else 0o644)
                if entry.isfile():
                    archived[entry.name.split("/", 1)[1]] = tar.extractfile(entry).read()
            self.assertEqual(archived, self.files)

    def test_conflicting_archive_refused_before_staging(self):
        archive = self.root / "package.tar.gz"
        archive.write_bytes(b"existing archive")
        with self.assertRaisesRegex(ValueError, "different archive"):
            self.stage(archive)
        self.assertEqual(archive.read_bytes(), b"existing archive")
        self.assertFalse(self.output.exists())
        with self.assertRaisesRegex(ValueError, "outside the staged package"):
            self.stage(self.output / "source.tar.gz")

    def test_cli_defaults_to_canonical_build_output(self):
        with patch.object(sys, "argv", ["build_ocaml_package.py"]):
            with patch.object(package, "stage", return_value=self.files) as stage:
                with contextlib.redirect_stdout(io.StringIO()):
                    package.main()
        stage.assert_called_once_with(package.ROOT / "build/ocaml-package", None, sync_split=False)

    def test_cli_explicit_output_and_archive(self):
        output = self.root / "existing-split"
        archive = self.root / "local.tar.gz"
        with patch.object(sys, "argv", ["build_ocaml_package.py", "--output", str(output), "--archive", str(archive)]):
            with patch.object(package, "stage", return_value=self.files) as stage:
                with contextlib.redirect_stdout(io.StringIO()):
                    package.main()
        stage.assert_called_once_with(output, archive, sync_split=False)

    def test_cli_sync_split_requires_explicit_output(self):
        with patch.object(sys, "argv", ["build_ocaml_package.py", "--sync-split"]):
            with patch.object(package, "stage") as stage, contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    package.main()
        self.assertEqual(error.exception.code, 2)
        stage.assert_not_called()
        with patch.object(sys, "argv", ["build_ocaml_package.py", "--output", str(self.output), "--sync-split"]):
            with patch.object(package, "stage", return_value=self.files) as stage:
                with contextlib.redirect_stdout(io.StringIO()):
                    package.main()
        stage.assert_called_once_with(self.output, None, sync_split=True)

    def split_fixture(self):
        self.output.mkdir()
        (self.output / ".git").mkdir()
        (self.output / ".git/config").write_bytes(b"untouched git metadata")
        (self.output / "README.md").write_bytes(b"existing tracked readme")
        (self.output / "unrelated.txt").write_bytes(b"unrelated tracked file")
        return {
            ("rev-parse", "--show-toplevel"): str(self.output),
            ("remote", "get-url", "--all", "origin"): "git@github.com:axisvela/praxo-core-ocaml.git",
            ("status", "--porcelain", "--untracked-files=all"): "",
            ("ls-files", "--stage", "-z"): "100644 abc 0\tREADME.md\0" + "100644 def 0\tunrelated.txt\0",
        }

    def snapshot(self):
        return {p.relative_to(self.output): p.read_bytes() for p in self.output.rglob("*") if p.is_file()}

    def test_sync_clean_split_preserves_unrelated_tracked_and_git(self):
        responses = self.split_fixture()
        for origin in ("git@github.com:axisvela/praxo-core-ocaml.git",
                       "https://github.com/axisvela/praxo-core-ocaml.git"):
            with self.subTest(origin=origin):
                responses[("remote", "get-url", "--all", "origin")] = origin
                with patch.object(package, "git", side_effect=lambda root, *args: responses[args]):
                    self.stage(sync_split=True)
                self.assertEqual((self.output / "README.md").read_bytes(), self.files["README.md"])
                self.assertEqual((self.output / "unrelated.txt").read_bytes(), b"unrelated tracked file")
                self.assertEqual((self.output / ".git/config").read_bytes(), b"untouched git metadata")
        for name, data in self.files.items():
            self.assertEqual((self.output / name).read_bytes(), data, name)

    def test_sync_rejects_wrong_remote_dirty_wrong_root_and_untracked_managed(self):
        responses = self.split_fixture()
        cases = [
            (("remote", "get-url", "--all", "origin"), remote, "Split origin")
            for remote in ("https://github.com/other/praxo-core-ocaml.git",
                           "https://github.com/axisvela/praxo-core-ocaml.git/extra",
                           "git@github.com:axisvela/praxo-core-ocaml.git.evil",
                           "https://github.com/axisvela/praxo-core-ocaml.git\nhttps://github.com/other/repo")
        ] + [
            (("status", "--porcelain", "--untracked-files=all"), status, "entirely clean")
            for status in (" M unrelated.txt", "M  README.md", "?? untracked.txt")
        ] + [
            (("rev-parse", "--show-toplevel"), str(self.root), "exact git top-level"),
            (("ls-files", "--stage", "-z"), "", "untracked managed"),
            (("ls-files", "--stage", "-z"), "120000 abc 0\tREADME.md\0", "untracked managed"),
        ]
        before = self.snapshot()
        for command, response, message in cases:
            with self.subTest(command=command, response=response):
                changed = dict(responses)
                changed[command] = response
                with patch.object(package, "git", side_effect=lambda root, *args: changed[args]):
                    with self.assertRaisesRegex(ValueError, message):
                        self.stage(sync_split=True)
                self.assertEqual(self.snapshot(), before)

    def test_sync_does_not_readopt_edited_generated_files(self):
        responses = self.split_fixture()
        with patch.object(package, "git", side_effect=lambda root, *args: responses[args]):
            self.stage(sync_split=True)
            (self.output / "README.md").write_bytes(b"committed edits to generated file")
            before = self.snapshot()
            with self.assertRaisesRegex(ValueError, "unowned or edited"):
                self.stage(sync_split=True)
        self.assertEqual(self.snapshot(), before)

    def test_sync_rejects_linked_managed_files(self):
        responses = self.split_fixture()
        readme = self.output / "README.md"
        elsewhere = self.root / "readme.md"
        try:
            os.link(readme, elsewhere)
        except OSError:
            self.skipTest("Hard link creation is not permitted")
        with patch.object(package, "git", side_effect=lambda root, *args: responses[args]):
            with self.assertRaisesRegex(ValueError, "hard-linked"):
                self.stage(sync_split=True)
        self.assertEqual(elsewhere.read_bytes(), b"existing tracked readme")

    def test_sync_rejects_symlink_managed_file(self):
        responses = self.split_fixture()
        target = self.output / "src"
        elsewhere = self.root / "elsewhere"
        elsewhere.mkdir()
        try:
            target.symlink_to(elsewhere, target_is_directory=True)
        except OSError:
            self.skipTest("Symlink creation is not permitted")
        with patch.object(package, "git", side_effect=lambda root, *args: responses[args]):
            with self.assertRaisesRegex(ValueError, "linked path"):
                self.stage(sync_split=True)
        self.assertEqual(list(elsewhere.iterdir()), [])

    def test_default_generated_refresh_does_not_require_clean_git(self):
        self.stage()
        (self.output / "untracked.txt").write_bytes(b"local notes")
        with patch.object(package, "git", side_effect=AssertionError("No split git checks in default mode")):
            self.stage()
        self.assertEqual((self.output / "untracked.txt").read_bytes(), b"local notes")

    def test_offline_full_payload_with_ocaml_compiler(self):
        compiler = shutil.which(os.environ.get("OCAMLC", "ocamlc"))
        runtime = shutil.which("ocamlrun")
        if not compiler or not runtime:
            self.skipTest("OCaml compiler/runtime not on PATH")
        self.stage()
        env = dict(os.environ, PYTHON=sys.executable)

        def run(args, cwd=self.output):
            result = subprocess.run(args, cwd=cwd, env=env, capture_output=True,
                                    stdin=subprocess.DEVNULL, timeout=120)
            self.assertEqual(result.returncode, 0, result.stdout.decode(errors="replace") + result.stderr.decode(errors="replace"))
            return result.stdout

        for source in ("src/praxo_core.mli", "src/praxo_core.ml", "tests/praxo_adapter_tests.ml", "tests/praxo_tests.ml"):
            run([compiler, "-g", "-I", "src", "-I", "tests", "-c", source])
        executable = self.output / "offline-tests.exe"
        run([compiler, "-g", "-I", "src", "-I", "tests", "-o", str(executable), "unix.cma",
             "src/praxo_core.cmo", "tests/praxo_adapter_tests.cmo", "tests/praxo_tests.cmo"])
        output = run([runtime, str(executable), "spec"], self.output / "tests")
        self.assertIn(b"OCaml Core tests passed", output)

    def test_dune_build_and_runtest_when_available(self):
        dune = shutil.which("dune")
        if not dune:
            self.skipTest("Dune not on PATH")
        self.stage()
        build = ["build", "--profile", "release", "src/praxo_core.cma"] if os.name == "nt" else ["build", "-p", "praxo-core"]
        for arguments in (build, ["runtest", "-p", "praxo-core"]):
            result = subprocess.run([dune, *arguments], cwd=self.output,
                                    env=dict(os.environ, PYTHON=sys.executable), capture_output=True,
                                    stdin=subprocess.DEVNULL, timeout=120)
            self.assertEqual(result.returncode, 0, result.stdout.decode(errors="replace") + result.stderr.decode(errors="replace"))

    def test_ci_installs_package_and_checks_external_consumer(self):
        workflow = (package.ROOT / ".github/workflows/ocaml-package.yml").read_text(encoding="utf-8")
        for command in (
            "opam lint build/ocaml-package/praxo-core.opam",
            "python -m tarfile -e build/praxo-core-ocaml-source.tar.gz build/ocaml-release-check",
            'opam install "./build/ocaml-release-check/praxo-core-$(cat language/ocaml/VERSION)" --with-test --yes',
            "opam exec -- dune exec --root language/ocaml/tests/package-consumer ./main.exe",
            'discover -s scripts -p "test_ocaml_*.py"',
        ):
            self.assertIn(command, workflow)
        self.assertIn('compiler: ["4.14.2", "5.5.0"]', workflow)
        consumer = package.ROOT / "language/ocaml/tests/package-consumer"
        self.assertIn("(libraries praxo-core)", (consumer / "dune").read_text())
        self.assertNotIn("praxo_core.ml", (consumer / "dune").read_text())


if __name__ == "__main__":
    unittest.main()
