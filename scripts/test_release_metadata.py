import json
import tempfile
import unittest
from pathlib import Path

import check_release_metadata as metadata


ROOT = Path(__file__).resolve().parents[1]


class ReleaseMetadataTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def build(self, version="2.6.0", spec="0.2.0", package_version=None):
        package_version = package_version or version
        self.write("VERSION", version + "\n")
        self.write(f"api/{version}.txt", "declaration\n")
        self.write(f"docs/releases/{version}.md", f"# PRAXO-CORE {version}\n")
        self.write(f"docs/zh-CN/releases/{version}.md", f"# PRAXO-CORE {version}\n")
        self.write(
            "docs/releases/index.md",
            f"Core `{version}` is the current framework release.\n\n| {version} | [notes]({version}.md) |\n",
        )
        self.write(
            "docs/zh-CN/releases/index.md",
            f"当前框架核心版本为 `{version}`。\n\n| {version} | [说明]({version}.md) |\n",
        )
        self.write("CHANGELOG.md", f"# Changelog\n\n## [{version}] - 2026-11-07\n")
        self.write("go.mod", "module github.com/axisvela/praxo-core/v2\n\ngo 1.25.0\n")
        self.write("spec/SPEC_VERSION", spec + "\n")
        self.write(
            "docs/getting-started/agent-integration.json",
            json.dumps({"specVersion": spec, "languages": [{"language": "Go", "version": package_version}]}),
        )
        self.write(
            "README.md",
            f"go get github.com/axisvela/praxo-core/v2@v{version}\n\n"
            f"- [Latest release notes](docs/releases/{version}.md)\n",
        )
        self.write(
            "docs/index.md",
            f"go get github.com/axisvela/praxo-core/v2@v{version}\n\n"
            f"See the [release notes](releases/{version}.md)\n",
        )
        self.write(
            "docs/zh-CN/index.md",
            f"go get github.com/axisvela/praxo-core/v2@v{version}\n\n"
            f"查看[最新发布说明](releases/{version}.md)\n",
        )
        self.write("docs/project/verification-evidence.md", "CI behavior job at commit `b6218e5`.\n")
        self.write("docs/zh-CN/project/verification-evidence.md", "commit `b6218e5` 的 CI behavior job。\n")
        self.write("docs/languages/behavior-lab-matrix.md", f"| Revision | `{'a' * 40}` |\n")
        self.write("docs/zh-CN/languages/behavior-lab-matrix.md", f"| Revision | `{'a' * 40}` |\n")

    def errors(self):
        return metadata.validate(self.root)

    def test_current_repository_passes(self):
        self.assertEqual(metadata.validate(ROOT), [])

    def test_valid_fixture_passes(self):
        self.build()
        self.assertEqual(self.errors(), [])

    def test_prerelease_version_is_rejected(self):
        self.build(version="2.6.0-rc.1")
        self.assertTrue(any("pre-release" in error for error in self.errors()))

    def test_missing_api_snapshot_is_rejected(self):
        self.build()
        (self.root / "api/2.6.0.txt").unlink()
        self.assertTrue(any("API snapshot" in error for error in self.errors()))

    def test_stale_release_index_is_rejected(self):
        self.build()
        self.write(
            "docs/releases/index.md",
            "Core `2.5.2` is the current framework release.\n\n| 2.5.2 | [notes](2.5.2.md) |\n",
        )
        self.assertTrue(any("current-version marker" in error for error in self.errors()))

    def test_go_module_major_must_match_version(self):
        self.build()
        self.write("go.mod", "module github.com/axisvela/praxo-core\n\ngo 1.25.0\n")
        self.assertTrue(any("must end with /v2" in error for error in self.errors()))

    def test_agent_map_must_match_version(self):
        self.build(package_version="2.5.2")
        self.assertTrue(any("Go version" in error for error in self.errors()))

    def test_recorded_ci_run_cannot_be_labeled_current(self):
        self.build()
        self.write("docs/project/verification-evidence.md", "the current CI behavior job\n")
        self.assertTrue(any("must not be labeled current" in error for error in self.errors()))

    def test_behavior_matrix_requires_full_revision(self):
        self.build()
        self.write("docs/languages/behavior-lab-matrix.md", "| Revision | `b6218e5` |\n")
        self.assertTrue(any("40-character Revision" in error for error in self.errors()))


if __name__ == "__main__":
    unittest.main()
