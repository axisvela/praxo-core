import re
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SDK = ROOT / "language" / "ocaml"


class OcamlApiDocsTests(unittest.TestCase):
    def setUp(self):
        self.mli = (SDK / "src" / "praxo_core.mli").read_text(encoding="utf-8")
        self.sources = sorted((SDK / "src").glob("*.ml"))
        self.ml = "\n".join(path.read_text(encoding="utf-8") for path in self.sources)

    def test_library_and_test_sources_live_in_subdirectories(self):
        for name in ("praxo_core.ml", "praxo_core.mli"):
            self.assertTrue((SDK / "src" / name).is_file(), name)
        for name in ("praxo_tests.ml", "praxo_adapter_tests.ml"):
            self.assertTrue((SDK / "tests" / name).is_file(), name)
        for stale in ("praxo_core.ml", "praxo_core.mli",
                      "praxo_tests.ml", "praxo_adapter_tests.ml"):
            self.assertFalse((SDK / stale).exists(), stale)

    def test_every_exported_value_has_an_attached_doc_comment(self):
        lines = self.mli.splitlines()
        values = 0
        for index, line in enumerate(lines):
            if not line.startswith("val "):
                continue
            values += 1
            declaration = [line]
            cursor = index + 1
            while cursor < len(lines) and lines[cursor].startswith("  "):
                declaration.append(lines[cursor])
                cursor += 1
            previous = lines[index - 1] if index else ""
            with self.subTest(value=line.split(":")[0], line=index + 1):
                self.assertTrue(
                    any("[@@ocaml.doc" in part for part in declaration) or
                    (previous.startswith("(**") and previous.endswith("*)")),
                    previous,
                )
        self.assertGreaterEqual(values, 100)

    def test_interface_stays_within_source_guardrail(self):
        self.assertLess(len(self.mli.splitlines()), 500)
        for path in self.sources:
            with self.subTest(source=path.name):
                self.assertLess(len(path.read_text(encoding="utf-8").splitlines()), 500)

    def test_duplicate_character_predicates_are_removed(self):
        self.assertNotIn("is_digit_char", self.ml)
        self.assertEqual(len(re.findall(r"^let is_alpha\b", self.ml, re.MULTILINE)), 1)
        self.assertRegex(self.ml, r"let starts_with prefix text = String\.starts_with")
        self.assertRegex(self.ml, r"let ends_with suffix text = String\.ends_with")
        self.assertIn("{ (text_message \"assistant\" content) with", self.ml)
        self.assertIn("{ (text_message \"tool\" content) with", self.ml)

    def test_api_snapshot_and_parity_still_match(self):
        result = subprocess.run(
            [sys.executable, str(SDK / "api-snapshot.py"), "--check"],
            cwd=ROOT, capture_output=True, text=True, timeout=120,
            stdin=subprocess.DEVNULL,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("current", result.stdout.lower())


if __name__ == "__main__":
    unittest.main()
