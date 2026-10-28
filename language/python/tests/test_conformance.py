from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import praxo
from praxo.conformance import run_all
from praxo.parity import check_parity


class ConformanceTest(unittest.TestCase):
    def test_spec_vectors(self) -> None:
        failures = run_all()
        if failures:
            self.fail("\n".join(str(failure) for failure in failures))

    def test_missing_vector_group_fails(self) -> None:
        source = Path(__file__).resolve().parents[3]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            vectors = root / "spec" / "vectors"
            vectors.mkdir(parents=True)
            shutil.copyfile(
                source / "spec" / "SPEC_VERSION",
                root / "spec" / "SPEC_VERSION",
            )
            shutil.copyfile(
                source / "spec" / "vectors" / "toolcall.json",
                vectors / "toolcall.json",
            )
            failures = run_all(root)
        details = "\n".join(str(failure) for failure in failures)
        self.assertIn(
            "agent-loop/agent-loop: missing required vector group",
            details,
        )

    def test_python_parity(self) -> None:
        failures = check_parity()
        if failures:
            self.fail("\n".join(failures))

    def test_version(self) -> None:
        self.assertEqual(praxo.__version__, "0.2.0")

    def test_spec_version_matches_contract(self) -> None:
        spec_version = (
            Path(__file__).resolve().parents[3]
            / "spec"
            / "SPEC_VERSION"
        ).read_text(encoding="utf-8").strip()
        self.assertEqual(praxo.SPEC_VERSION, spec_version)

    def test_public_api(self) -> None:
        self.assertTrue(callable(praxo.Agent))
        self.assertTrue(callable(praxo.parse_tool_call))


if __name__ == "__main__":
    unittest.main()
