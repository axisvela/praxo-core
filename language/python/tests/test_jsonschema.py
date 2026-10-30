from __future__ import annotations

import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.jsonschema import Schema


class JsonSchemaTest(unittest.TestCase):
    def test_integer_rejects_fractions(self) -> None:
        schema = Schema(type="integer")
        self.assertEqual(schema.validate(2), [])
        self.assertEqual(len(schema.validate(2.5)), 1)

    def test_length_counts_unicode_code_points(self) -> None:
        schema = Schema(type="string", min_length=2, max_length=2)
        self.assertEqual(schema.validate("你好"), [])
        self.assertEqual(len(schema.validate("你")), 1)


if __name__ == "__main__":
    unittest.main()
