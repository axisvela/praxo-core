import unittest

import check_example_coverage as coverage


class ExampleCoverageTests(unittest.TestCase):
    def test_current_catalog_is_complete(self):
        self.assertEqual(coverage.missing(), [])
        self.assertEqual(coverage.missing_ci(), [])
        self.assertEqual(coverage.main(), 0)

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
