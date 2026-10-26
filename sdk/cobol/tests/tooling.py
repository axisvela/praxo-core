import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from conformance import GROUPS, emit_checks, literal

spec = importlib.util.spec_from_file_location(
    "api_snapshot", ROOT / "api-snapshot.py")
api_snapshot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api_snapshot)


class ToolingTests(unittest.TestCase):
    def test_literal_preserves_controls_and_unicode(self):
        self.assertEqual(literal("a'b"), "'a''b'")
        self.assertEqual(literal("\n\x00"), 'x"0a00"')
        self.assertEqual(literal("\u00e9"), 'x"c3a9"')
        self.assertEqual(literal(""), "spaces")

    def test_all_vector_groups_are_declared(self):
        actual = {path.stem for path in
                  (ROOT.parent.parent / "spec" / "vectors").glob("*.json")}
        self.assertEqual(set(GROUPS), actual)

    def test_assertion_emitter_checks_truth(self):
        lines = []
        emit_checks(lines, "case", ["x = 1"])
        self.assertIn("move 0 to assertion-ok", lines)
        self.assertIn("if x = 1 move 1 to assertion-ok end-if", lines)

    def test_snapshot_detects_wire_changes(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            root = Path(directory)
            (root / "src").mkdir()
            (root / "copy").mkdir()
            copy = root / "copy" / "api.cpy"
            copy.write_text("       01 payload.\n          05 value pic x(8).\n",
                            encoding="utf-8")
            source = root / "src" / "agent.cob"
            source.write_text(
                "identification division.\nprogram-id. run.\n"
                "procedure division using request result.\n", encoding="utf-8")
            original = api_snapshot.snapshot(root)
            copy.write_text(
                "       01 payload.\n          05 value pic x(16).\n",
                encoding="utf-8")
            self.assertNotEqual(original, api_snapshot.snapshot(root))
            copy.write_text(
                "       01 payload.\n          05 value pic x(8).\n",
                encoding="utf-8")
            source.write_text(
                "identification division.\nprogram-id. run.\n"
                "procedure division using request result extra.\n",
                encoding="utf-8")
            self.assertNotEqual(original, api_snapshot.snapshot(root))

    def test_source_size_guardrail(self):
        for path in (ROOT / "src").glob("*.cob"):
            with self.subTest(path=path.name):
                self.assertLess(len(path.read_text(encoding="utf-8").splitlines()),
                                500)


if __name__ == "__main__":
    (ROOT / "build").mkdir(exist_ok=True)
    unittest.main()
