import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PREFIX = "https://github.com/axisvela/praxo-core/blob/main/"
REQUIRED = [
    "README.md",
    "docs/getting-started/quickstart.md",
    "docs/getting-started/index.md",
    "docs/getting-started/when-not-to-use.md",
    "docs/getting-started/coding-agents.md",
    "docs/getting-started/agent-integration.json",
    "docs/getting-started/consumer-go.md",
    "docs/getting-started/consumer-python.md",
    "docs/getting-started/consumer-typescript.md",
    "docs/getting-started/consumer-java.md",
    "docs/guides/recipes.md",
    "docs/project/roadmap.md",
    "docs/reference/execution-profiles.md",
    "docs/project/execution-correctness.md",
    "docs/project/verification-evidence.md",
    "agent-skills/praxo-integration/SKILL.md",
    "CHANGELOG.md",
]


class LlmsTxtTests(unittest.TestCase):
    def setUp(self):
        self.path = ROOT / "llms.txt"
        self.text = self.path.read_text(encoding="utf-8")

    def test_header_and_required_links(self):
        self.assertTrue(self.text.startswith("# PRAXO-CORE\n"))
        for relative in REQUIRED:
            with self.subTest(path=relative):
                self.assertIn(PREFIX + relative, self.text)

    def test_links_resolve_to_repository_files(self):
        targets = re.findall(r"\]\((https://[^)]+)\)", self.text)
        self.assertTrue(targets)
        for target in targets:
            with self.subTest(target=target):
                self.assertTrue(target.startswith(PREFIX), target)
                relative = target[len(PREFIX):]
                self.assertTrue((ROOT / relative).is_file(), relative)

    def test_no_private_or_local_hosts(self):
        lowered = self.text.lower()
        for needle in (".internal", "localhost", "127.0.0.1", "axisrobo"):
            with self.subTest(needle=needle):
                self.assertNotIn(needle, lowered)


if __name__ == "__main__":
    unittest.main()
