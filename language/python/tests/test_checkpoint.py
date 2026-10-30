from __future__ import annotations

import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.checkpoint import Allowlist
from praxo.errors import TypeNotAllowedError


class CheckpointTest(unittest.TestCase):
    def test_allowlist_round_trips_content(self) -> None:
        allow = Allowlist()
        allow.register("spec.payload", dict)
        encoded = allow.marshal(
            "spec.payload",
            {"text": "你好", "nested": {"value": 7}},
        )
        restored = allow.unmarshal(encoded)
        self.assertEqual(restored, {"text": "你好", "nested": {"value": 7}})

    def test_unknown_payload_type_is_rejected(self) -> None:
        allow = Allowlist()
        with self.assertRaises(TypeNotAllowedError):
            allow.marshal("spec.missing", {})


if __name__ == "__main__":
    unittest.main()
