from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
COUNTS = {"SE": 8, "OP": 7, "CS": 7, "FC": 6, "SC": 6, "IN": 6, "HC": 5, "PE": 5}
SECOND_BATCH = {"CY": 7, "CT": 7, "TL": 7, "MD": 7, "LJ": 5, "BE": 5, "AE": 5, "OG": 7}
COUNTS.update(SECOND_BATCH)
CORES = {
    "go", "python", "typescript", "java", "rust", "csharp", "r", "c", "cpp",
    "fortran", "cobol", "php", "ruby", "elixir", "erlang", "lua", "dart",
    "swift", "julia", "haskell", "matlab", "octave", "perl", "delphi", "ocaml",
    "objc", "nim", "v", "d", "zig", "powershell",
}


class ScenarioCatalogTest(unittest.TestCase):
    def test_bilingual_catalogs(self):
        expected = {f"{group}-{i:02}" for group, count in COUNTS.items()
                    for i in range(1, count + 1)}
        for locale in ("", "zh-CN/"):
            with self.subTest(locale=locale):
                text = (ROOT / f"docs/{locale}getting-started/agent-scenarios.md").read_text(encoding="utf-8")
                rows = re.findall(r"^\| ([A-Z]{2}-\d{2}) \| (.+)$", text, re.M)
                self.assertEqual(len(rows), 100)
                self.assertEqual({key for key, _ in rows}, expected)
                assignments = re.findall(r"^\| `([a-z]+)` \| ([^|]+) \|", text, re.M)
                self.assertEqual(len(assignments), 31)
                self.assertEqual({language for language, _ in assignments}, CORES)
                for language, ids in assignments:
                    self.assertTrue((ROOT / "language" / language).is_dir())
                    self.assertTrue(set(re.findall(r"[A-Z]{2}-\d{2}", ids)) <= expected)
                    self.assertRegex(ids, r"[A-Z]{2}-\d{2}")

    def test_second_batch_separates_slices_from_full_implementation(self):
        for locale in ("", "zh-CN/"):
            text = (ROOT / f"docs/{locale}getting-started/agent-scenarios.md").read_text(encoding="utf-8")
            rows = [line for line in text.splitlines()
                    if any(line.startswith(f"| {prefix}-") for prefix in SECOND_BATCH)]
            self.assertEqual(len(rows), 50)
            for row in rows:
                cells = [cell.strip() for cell in row.split("|")[1:-1]]
                with self.subTest(locale=locale, scenario=cells[0]):
                    self.assertEqual(len(cells), 6)
                    self.assertTrue(cells[4])
                    self.assertEqual(cells[5], "未实现" if locale else "Not implemented")


    def test_related_source_paths_exist(self):
        text = (ROOT / "docs/getting-started/agent-scenarios.md").read_text(encoding="utf-8")
        prefix = "https://github.com/axisvela/praxo-core/tree/main/"
        paths = re.findall(re.escape(prefix) + r"([^\s)]+)", text)
        self.assertGreater(len(paths), 10)
        for path in paths:
            with self.subTest(path=path):
                self.assertTrue((ROOT / path / "README.md").is_file())

    def test_navigation_and_plan_links(self):
        nav = (ROOT / "mkdocs.yml").read_text(encoding="utf-8")
        self.assertIn("Agent Scenarios: getting-started/agent-scenarios.md", nav)
        for locale in ("", "zh-CN/"):
            plan = (ROOT / f"docs/{locale}getting-started/tutorial-plan.md").read_text(encoding="utf-8")
            self.assertIn("(agent-scenarios.md)", plan)


if __name__ == "__main__":
    unittest.main()
