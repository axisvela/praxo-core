from __future__ import annotations

import dataclasses
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "praxo_api_signatures", ROOT / "api-signatures.py"
)
API = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(API)


@dataclasses.dataclass
class Sample:
    name: str
    count: int = 0

    def run(self, value: str) -> int:
        return len(value) + self.count

    @property
    def label(self) -> str:
        return self.name


@dataclasses.dataclass
class Mutated:
    name: int
    count: str = "0"

    def run(self, value: int) -> str:
        return str(value) + self.count


class ApiSignatureTests(unittest.TestCase):
    def test_class_fields_constructor_methods_and_properties(self) -> None:
        output = "\n".join(API.class_lines(Sample, "Sample"))
        for expected in (
            "class Sample",
            "constructor(name: 'str', count: 'int' = 0) -> None",
            "field name: str",
            "field count: int = 0",
            "method run(value: 'str') -> 'int'",
            "property label -> 'str'",
        ):
            self.assertIn(expected, output)

    def test_same_name_type_changes_alter_signatures(self) -> None:
        original = "\n".join(API.class_lines(Sample, "Sample"))
        changed = "\n".join(API.class_lines(Mutated, "Sample"))
        for expected in (
            "field name: int",
            "field count: str = '0'",
            "method run(value: 'int') -> 'str'",
        ):
            self.assertIn(expected, changed)
        self.assertNotEqual(original, changed)

    def test_function_signature_and_defaults(self) -> None:
        def function(value: str, count: int = 2) -> bool:
            return bool(value and count)

        output = "\n".join(API.function_lines(function, "function"))
        self.assertIn("function function(value: 'str', count: 'int' = 2) -> 'bool'", output)

    def test_checked_in_signature_snapshot_is_current(self) -> None:
        path = ROOT / "api" / f"{API.praxo.__version__}.signatures.txt"
        self.assertTrue(path.is_file(), path)
        self.assertEqual(path.read_text(encoding="utf-8"), API.snapshot())


if __name__ == "__main__":
    unittest.main()
