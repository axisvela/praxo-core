import json
import tempfile
import unittest
from pathlib import Path

import release_manifest as manifest


class ReleaseManifestTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "sbom.json").write_text("{}\n", encoding="utf-8")
        (self.root / "praxo-core-2.5.0.tar.gz").write_bytes(b"archive")

    def build(self, **changes):
        values = {
            "version": "2.5.0",
            "tag": "v2.5.0",
            "sha": "a" * 40,
            "go_version": "go version go1.26.10 linux/amd64",
            "spec_version": "0.2.0",
            "sbom_scope": "root Go module dependencies only",
        }
        values.update(changes)
        return manifest.build_manifest(self.root, **values)

    def test_manifest_and_checksums_cover_all_attachments(self):
        built = self.build()
        loaded = json.loads((self.root / "release-manifest.json").read_text())
        self.assertEqual(built, loaded)
        names = [item["name"] for item in loaded["artifacts"]]
        self.assertEqual(names, ["praxo-core-2.5.0.tar.gz", "sbom.json"])
        self.assertEqual(loaded["sbom"]["scope"], "root Go module dependencies only")
        sums = (self.root / "SHA256SUMS").read_text().splitlines()
        self.assertEqual(len(sums), 3)
        self.assertIn("  release-manifest.json", "\n".join(sums))
        self.assertIn("  sbom.json", "\n".join(sums))
        self.assertNotIn("  SHA256SUMS", "\n".join(sums))

    def test_repeated_build_is_deterministic(self):
        self.build()
        first = {
            name: (self.root / name).read_bytes()
            for name in ("release-manifest.json", "SHA256SUMS")
        }
        self.build()
        for name, content in first.items():
            self.assertEqual(content, (self.root / name).read_bytes())

    def test_manifest_hashes_match_artifacts(self):
        self.build()
        loaded = json.loads((self.root / "release-manifest.json").read_text())
        for item in loaded["artifacts"]:
            self.assertEqual(
                manifest.sha256(self.root / item["name"]), item["sha256"]
            )

    def test_tag_version_sha_and_required_files_fail_closed(self):
        cases = [
            {"version": "2.5"},
            {"tag": "v2.5.1"},
            {"sha": "a" * 39},
            {"sha": "A" * 40},
            {"go_version": " "},
            {"spec_version": ""},
            {"sbom_scope": ""},
        ]
        for changes in cases:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.build(**changes)
        (self.root / "sbom.json").unlink()
        with self.assertRaisesRegex(ValueError, "sbom.json"):
            self.build()
        self.assertFalse((self.root / "release-manifest.json").exists())

    def test_empty_distribution_fails_without_writing(self):
        (self.root / "sbom.json").unlink()
        (self.root / "praxo-core-2.5.0.tar.gz").unlink()
        with self.assertRaisesRegex(ValueError, "no release artifacts"):
            self.build()
        self.assertFalse((self.root / "SHA256SUMS").exists())


if __name__ == "__main__":
    unittest.main()
