import asyncio
import json
import tempfile
import unittest
from pathlib import Path

from app import FixtureModel, process_directory


class StructuredOutputAppTests(unittest.TestCase):
    def test_processes_valid_and_records_invalid(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            inputs = root / "inputs"
            inputs.mkdir()
            (inputs / "quarterly.txt").write_text(
                "Quarterly status: all checks green.", encoding="utf-8"
            )
            (inputs / "invalid.txt").write_text(
                "invalid payload: the model omits required fields", encoding="utf-8"
            )
            output = root / "out" / "results.jsonl"
            errors = root / "out" / "errors.jsonl"

            counts = asyncio.run(
                process_directory(inputs, output, errors, FixtureModel())
            )

            self.assertEqual(counts, {"processed": 1, "skipped": 0, "failed": 1})
            results = [json.loads(line) for line in output.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(len(results), 1)
            self.assertEqual(results[0]["source"], "quarterly.txt")
            self.assertEqual(
                set(results[0]["result"]), {"title", "summary", "tags"}
            )
            failures = [json.loads(line) for line in errors.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(len(failures), 1)
            self.assertEqual(failures[0]["source"], "invalid.txt")
            self.assertEqual(failures[0]["error"], "StructuredOutputError")

    def test_resume_skips_successful_outputs_and_retries_failures(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            inputs = root / "inputs"
            inputs.mkdir()
            (inputs / "quarterly.txt").write_text(
                "Quarterly status: all checks green.", encoding="utf-8"
            )
            (inputs / "invalid.txt").write_text(
                "invalid payload: the model omits required fields", encoding="utf-8"
            )
            output = root / "out" / "results.jsonl"
            errors = root / "out" / "errors.jsonl"

            asyncio.run(process_directory(inputs, output, errors, FixtureModel()))
            counts = asyncio.run(
                process_directory(inputs, output, errors, FixtureModel(), resume=True)
            )

            self.assertEqual(counts, {"processed": 0, "skipped": 1, "failed": 1})
            results = [json.loads(line) for line in output.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(len(results), 1)
            failures = [json.loads(line) for line in errors.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(len(failures), 2)


if __name__ == "__main__":
    unittest.main()
