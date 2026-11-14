import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import check_language_releases as releases


ROOT = Path(__file__).resolve().parents[1]
TAG = "python/v0.8.0"


class LanguageReleaseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.build()

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def build(self):
        self.write(
            "language/registry-metadata.json",
            json.dumps(
                {
                    "Python": {
                        "dir": "language/python",
                        "published_version": "0.7.0",
                        "source_version": "0.8.0",
                        "tag": TAG,
                        "tier": "Core",
                    }
                }
            ),
        )
        self.write("language/python/pyproject.toml", '[project]\nversion = "0.8.0"\n')
        self.write(
            "language/python/CHANGELOG.md",
            "# Python\n\n## 0.8.0 - 2026-11-14\n\n- change\n\n## 0.7.0 - 2026-11-13\n\n- published\n",
        )
        self.write(
            "spec/languages.md",
            "## Matrix\n\n"
            "| Language | Tier | Status | Tag | Maturity | Notes |\n"
            "| --- | --- | --- | --- | --- | --- |\n"
            f"| Python | Core | released | `{TAG}` | complete | note |\n",
        )
        self.write(
            "docs/languages/support.md",
            "### Registry freshness against code\n\n"
            "| Language | Code/manifest version | Registry latest | Status |\n"
            "| --- | --- | --- | --- |\n"
            "| Python | `0.8.0` | PyPI `0.7.0` | tag released; registry behind |\n",
        )

    def errors(self):
        with patch.object(releases, "_git_tags", return_value={TAG}):
            return releases.validate(self.root)

    def test_current_repository_passes(self):
        self.assertEqual(releases.validate(ROOT), [])

    def test_valid_fixture_passes(self):
        self.assertEqual(self.errors(), [])

    def test_missing_tag_is_rejected(self):
        with patch.object(releases, "_git_tags", return_value=set()):
            self.assertTrue(any("does not exist" in error for error in releases.validate(self.root)))

    def test_tag_check_can_be_disabled(self):
        with patch.object(releases, "_git_tags", return_value=set()):
            self.assertEqual(releases.validate(self.root, check_tags=False), [])

    def test_manifest_version_must_match_source_version(self):
        self.write("language/python/pyproject.toml", '[project]\nversion = "0.7.0"\n')
        self.assertTrue(any("manifest version" in error for error in self.errors()))

    def test_source_tag_requires_release_notes(self):
        self.write("language/python/CHANGELOG.md", "# Python\n\n## 0.7.0 - 2026-11-14\n")
        self.assertTrue(any("missing release notes" in error for error in self.errors()))

    def test_primary_registry_publish_requires_release_notes(self):
        self.write("language/python/CHANGELOG.md", "# Python\n\n## 0.8.0 - 2026-11-14\n")
        self.assertTrue(
            any("published version '0.7.0'" in error for error in self.errors())
        )

    def test_matrix_status_and_tag_must_match_metadata(self):
        self.write(
            "spec/languages.md",
            "## Matrix\n\n"
            "| Language | Tier | Status | Tag | Maturity | Notes |\n"
            "| --- | --- | --- | --- | --- | --- |\n"
            "| Python | Core | in progress | none | complete | note |\n",
        )
        errors = self.errors()
        self.assertTrue(any("status is 'in progress'" in error for error in errors))
        self.assertTrue(any("tag is 'none'" in error for error in errors))

    def test_support_page_versions_must_match_metadata(self):
        self.write(
            "docs/languages/support.md",
            "### Registry freshness against code\n\n"
            "| Language | Code/manifest version | Registry latest | Status |\n"
            "| --- | --- | --- | --- |\n"
            "| Python | `0.7.0` | PyPI `0.8.0` | stale |\n",
        )
        errors = self.errors()
        self.assertTrue(any("code version" in error for error in errors))
        self.assertTrue(any("registry version" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
