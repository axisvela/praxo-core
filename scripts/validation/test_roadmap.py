import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


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

    def test_reference_applications_are_ordered_and_bilingual(self):
        expected = ["PHP", "Java", "Elixir / Erlang", "Go", "C++ / Rust", "COBOL", "Julia", "Ruby"]
        for prefix in ("", "zh-CN/"):
            with self.subTest(language=prefix):
                text = (ROOT / "docs" / prefix / "project/roadmap.md").read_text(encoding="utf-8")
                rows = re.findall(r"^\| ([1-8]) \| ([^|]+) \|", text, re.MULTILINE)
                self.assertEqual(rows, [(str(i), name) for i, name in enumerate(expected, 1)])
                for marker in ("Laravel", "Spring Boot", "OTP", "Rails", "P0", "P1", "P2"):
                    self.assertIn(marker, text)

    def test_tutorial_ci_snapshot_replaces_pending_status(self):
        for prefix in ("", "zh-CN/"):
            for page in ("project/roadmap.md", "getting-started/tutorial-plan.md",
                         "getting-started/runtime-scenario-design.md", "project/verification-evidence.md"):
                with self.subTest(language=prefix, page=page):
                    text = (ROOT / "docs" / prefix / page).read_text(encoding="utf-8")
                    self.assertIn("dfdfd558", text)
                    self.assertIn("45537631891", text)
                    if "runtime-scenario-design" not in page:
                        self.assertNotRegex(text, r"(?i)CI job.{0,30}not yet run")
                        self.assertNotRegex(text, r"CI job.{0,20}尚未运行")

    def test_selection_plan_keeps_unrun_status_and_existing_upgrade_evidence(self):
        for prefix in ("", "zh-CN/"):
            with self.subTest(language=prefix):
                text = (ROOT / "docs" / prefix / "project/adoption-baseline.md").read_text(encoding="utf-8")
                self.assertIn("Agent Selection Benchmark", text)
                self.assertIn("upgrade-python-002", text)
                self.assertIn("top-1/top-3", text)
                self.assertNotIn("No upgrade or retention results exist", text)
                self.assertNotIn("没有升级或留存数据", text)

    def test_verification_registry_links_match_current_releases(self):
        registry = (ROOT / "docs/languages/registry-status.md").read_text(encoding="utf-8")
        versions = {}
        for line in registry.splitlines():
            if not line.startswith("| "):
                continue
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if len(cells) >= 3 and re.fullmatch(r"`[^`]+`", cells[2]):
                versions[cells[0]] = cells[2].strip("`")
        packages = (
            ("Python", "praxo-core"),
            ("TypeScript", "@axisvela/praxo-core"),
            ("Java", "com.axisvela:praxo-core"),
            ("Rust", "praxo-core"),
            ("C#", "Praxo.Core"),
            ("Elixir", "praxo_core"),
            ("Erlang", "praxo_core_erlang"),
            ("Ruby", "praxo-core"),
            ("Lua", "praxo-core"),
            ("PHP", "axisvela/praxo-core"),
            ("Dart", "praxo_core"),
            ("D", "praxo-core"),
            ("PowerShell Core", "praxo-core-ps"),
            ("Perl", "Praxo-Core"),
        )
        for prefix, heading, end in (
            ("", "## Public Evidence Links", "## Not Claimed"),
            ("zh-CN/", "## 公开证据链接", "## 未声明"),
        ):
            text = (ROOT / "docs" / prefix / "project/verification-evidence.md").read_text(encoding="utf-8")
            block = text.split(heading, 1)[1].split(end, 1)[0]
            for registry_name, label in packages:
                with self.subTest(language=prefix, package=label):
                    self.assertIn(f"{label} {versions[registry_name]}", block)

    def test_reference_applications_use_language_application_directory(self):
        apps = sorted((ROOT / "language").glob("*/application"))
        self.assertTrue(any(path.parent.name == "php" for path in apps))
        for path in apps:
            with self.subTest(application=path.as_posix()):
                self.assertTrue((path / "README.md").is_file())
        self.assertFalse((ROOT / "language/php/Tutorial/laravel-business-agent").exists())
        php = ROOT / "language/php/application"
        self.assertTrue((php / "README.md").is_file())
        self.assertFalse((php / "composer.json").exists())
        for name in ("content-review", "ai-editorial-studio"):
            with self.subTest(variant=name):
                self.assertTrue((php / name / "README.md").is_file())
        ai_readme = (php / "ai-editorial-studio/README.md").read_text(encoding="utf-8")
        self.assertIn("AI-native", ai_readme)
        precursor_readme = (php / "content-review/README.md").read_text(encoding="utf-8")
        self.assertIn("precursor", precursor_readme)
        roadmap = (ROOT / "docs/project/roadmap.md").read_text(encoding="utf-8")
        self.assertIn("language/<language>/application/", roadmap)

    def test_readme_latest_release_notes_match_current_release(self):
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        for readme in ("README.md", "README.zh-CN.md"):
            with self.subTest(readme=readme):
                text = (ROOT / readme).read_text(encoding="utf-8")
                self.assertIn(f"releases/{version}.md", text)

    def test_presentation_releases_match_registry_status(self):
        matrix = (ROOT / "spec/languages.md").read_text(encoding="utf-8")
        registry = (ROOT / "docs/languages/registry-status.md").read_text(encoding="utf-8")
        metadata = json.loads((ROOT / "language/registry-metadata.json").read_text(encoding="utf-8"))
        for language in ("Ruby", "PowerShell", "Perl", "Lua"):
            version = metadata[language]["published_version"]
            with self.subTest(language=language):
                row = next(line for line in matrix.splitlines() if line.startswith(f"| {language} |"))
                registry_name = "PowerShell Core" if language == "PowerShell" else language
                published = next(line for line in registry.splitlines() if line.startswith(f"| {registry_name} |"))
                self.assertIn(f"=={version}`", row)
                self.assertIn(f"`{version}`", published)
                self.assertNotIn("publication pending", row)


if __name__ == "__main__":
    unittest.main()
