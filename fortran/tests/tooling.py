import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from conformance import GROUPS, generate, literal

spec = importlib.util.spec_from_file_location("api_snapshot", ROOT / "api-snapshot.py")
api_snapshot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api_snapshot)


class ToolingTests(unittest.TestCase):
    def test_literal_preserves_controls_unicode_and_quotes(self):
        self.assertEqual(literal("a'b"), "'a''b'")
        self.assertEqual(literal("\n\r\x00"), "char(10)//char(13)//char(0)")
        self.assertEqual(literal("\u00e9"), "char(195)//char(169)")
        self.assertEqual(literal(""), "''")

    def test_all_vector_groups_are_declared(self):
        actual = {path.stem for path in (ROOT.parent / "spec" / "vectors").glob("*.json")}
        self.assertEqual(set(GROUPS), actual)

    def test_fixture_generation_is_deterministic(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            output = Path(directory) / "fixtures.f90"
            generate(ROOT, output)
            expected = output.read_bytes()
            generate(ROOT, output)
            self.assertEqual(expected, output.read_bytes())

    def test_snapshot_detects_type_and_signature_changes(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            root = Path(directory)
            (root / "src").mkdir()
            path = root / "src" / "sample.f90"
            source = """module sample
private
public :: options, run
type :: options
integer :: budget
end type
contains
subroutine run(value)
integer, intent(in) :: value
print *, value
end subroutine
end module
"""
            path.write_text(source, encoding="utf-8")
            original = api_snapshot.snapshot(root)
            path.write_text(source.replace("integer :: budget", "real :: budget"), encoding="utf-8")
            self.assertNotEqual(original, api_snapshot.snapshot(root))
            path.write_text(source.replace("integer, intent", "real, intent"), encoding="utf-8")
            self.assertNotEqual(original, api_snapshot.snapshot(root))
            path.write_text(source.replace("print *, value", "print *, 0"), encoding="utf-8")
            self.assertEqual(original, api_snapshot.snapshot(root))

    def test_source_size_guardrail(self):
        for path in (ROOT / "src").glob("*.f90"):
            with self.subTest(path=path.name):
                self.assertLess(len(path.read_text(encoding="utf-8").splitlines()), 500)


if __name__ == "__main__":
    (ROOT / "build").mkdir(exist_ok=True)
    unittest.main()
