import tempfile
import unittest
from pathlib import Path

import check_example_coverage as coverage


class ExampleCoverageTests(unittest.TestCase):
    def test_current_catalog_is_complete(self):
        self.assertEqual(coverage.missing(), [])
        self.assertEqual(coverage.missing_code(), [])
        self.assertEqual(coverage.missing_ci(), [])
        self.assertEqual(coverage.main([]), 0)

    def test_readme_only_directory_is_not_an_implementation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "README.md").write_text("# Example\n", encoding="utf-8")
            self.assertEqual(coverage.implementation_files(path), [])
            (path / "main.py").write_text("print('ok')\n", encoding="utf-8")
            self.assertTrue(coverage.implementation_files(path))

    def test_report_includes_special_layouts(self):
        report = "\n".join(coverage.report_lines())
        self.assertIn("go | 13/13 (root examples)", report)
        self.assertIn("octave | 13/13 (MATLAB fallback)", report)
        self.assertIn("objc | 13/13", report)

    def test_advanced_report_lists_current_examples(self):
        report = "\n".join(coverage.advanced_report_lines())
        self.assertIn("go | advanced-delegation", report)
        self.assertIn("python | advanced-delegation", report)
        self.assertIn("typescript | advanced-delegation", report)
        self.assertIn("java | advanced-delegation", report)
        self.assertIn("csharp | advanced-delegation", report)
        self.assertIn("rust | advanced-delegation", report)

    def test_depth_report_covers_themes_and_reports_mechanism_checks(self):
        report = "\n".join(coverage.depth_report_lines())
        self.assertIn("consumer | 31/31", report)
        self.assertIn("retry | 8/31", report)
        self.assertIn("mcp | 27/31", report)
        self.assertIn("c, cobol", report)
        self.assertIn("Core reference", report)

    def test_r_source_core_usage_is_not_a_mechanism_check(self):
        self.assertTrue(
            coverage.uses_core("r", 'source("language/r/R/core.R")')
        )
        self.assertFalse(coverage.uses_core("r", "run <- function() NULL"))

    def test_sample_only_directories_are_excluded(self):
        languages = set(coverage.languages())
        self.assertTrue(
            languages.isdisjoint(
                {"clojure", "fsharp", "groovy", "javascript", "kotlin", "opencl", "scala"}
            )
        )
        self.assertIn("go", languages)
        self.assertIn("python", languages)
        self.assertIn("objc", languages)


if __name__ == "__main__":
    unittest.main()
