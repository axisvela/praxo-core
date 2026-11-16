import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class RoadmapTests(unittest.TestCase):
    def test_adoption_stages_are_unique_and_bilingual(self):
        for prefix in ("", "zh-CN/"):
            with self.subTest(language=prefix):
                text = (ROOT / "docs" / prefix / "project/roadmap.md").read_text(encoding="utf-8")
                stages = re.findall(r"^\| ([0-5])\. ", text, re.MULTILINE)
                self.assertEqual(stages, list("012345"))

    def test_memory_status_names_source_and_published_scope(self):
        for prefix in ("", "zh-CN/"):
            with self.subTest(language=prefix):
                text = (ROOT / "docs" / prefix / "project/contract-status.md").read_text(encoding="utf-8")
                row = next(line for line in text.splitlines() if line.startswith("| ") and "73da5139" in line)
                for marker in ("Go", "2.9.0", "system", "SDK"):
                    self.assertIn(marker, row)

    def test_tutorial_does_not_claim_identical_schemas(self):
        for prefix in ("", "zh-CN/"):
            with self.subTest(language=prefix):
                text = (ROOT / "docs" / prefix / "guides/structured-output-tutorial.md").read_text(encoding="utf-8")
                self.assertIn("`name`", text)
                self.assertNotIn("Each example validates `title`, `summary`, and `tags`", text)
                self.assertNotIn("每个示例都会在返回模型输出前校验", text)


if __name__ == "__main__":
    unittest.main()
