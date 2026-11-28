import copy
import json
from pathlib import Path
import re
import tempfile
from types import SimpleNamespace
import tomllib
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

from scripts.discovery import registry_catalog as catalog
from scripts.discovery import docs_hooks
from scripts.discovery.registry_discovery import CONFIG, ROOT, discovery, product_intro
from scripts.discovery import repository_discovery as repositories
from scripts.discovery import sync_language_mirrors as mirrors
from scripts.discovery import sync_language_registry_docs as registry


class DiscoveryTests(unittest.TestCase):
    def test_topic_configuration_covers_mirrors_and_splits(self):
        manifest = registry.manifest_data()
        proposal = repositories.proposal(manifest)
        self.assertEqual(len(proposal), 32)
        self.assertEqual(sum(item["kind"] == "discovery-mirror" for item in proposal.values()), 22)
        self.assertEqual(sum(item["kind"] == "publication-source" for item in proposal.values()), 9)
        self.assertEqual(set(CONFIG["language_topics"]), set(mirrors.MIRROR_KEYS) | set(CONFIG["split_sources"]))
        self.assertIn("axisvela/praxo-core-Julia", proposal)
        self.assertNotIn("axisvela/praxo-core-matlab-octave-core", proposal)
        for entry in registry.LANGUAGES:
            data = discovery(entry)
            if data["repository_kind"] == "shared-source":
                self.assertEqual(data["topics"], [])
                continue
            key = "go" if entry["dir"] == "." else Path(entry["dir"]).name
            self.assertTrue(set(CONFIG["language_topics"][key]) <= set(data["topics"]))

    def test_topic_validation_rejects_stale_metadata(self):
        manifest = registry.manifest_data()
        manifest["Python"]["discovery"]["topics"] = ["python"]
        with self.assertRaisesRegex(ValueError, "stale discovery"):
            repositories.proposal(manifest)

    def test_topic_validation_rejects_registry_limit_and_unknown_languages(self):
        for topics in (["same"] * 2, [f"topic-{index}" for index in range(21)], ["Upper_Case"]):
            config = copy.deepcopy(CONFIG)
            config["canonical_topics"] = topics
            with patch.dict(CONFIG, config, clear=True), self.assertRaises(ValueError):
                repositories.proposal(registry.manifest_data())
        manifest = registry.manifest_data()
        del manifest["Python"]
        with self.assertRaisesRegex(ValueError, "exactly the independent SDKs"):
            repositories.proposal(manifest)

    def test_alias_in_natural_introductions(self):
        for entry in registry.LANGUAGES:
            directory = ROOT / entry["dir"]
            with self.subTest(language=entry["name"]):
                intro = (directory / "README.md").read_text(encoding="utf-8").split("\n## ", 1)[0]
                self.assertIn("praxocore", intro.lower())
                for name in ("REGISTRY.md", "llms.md"):
                    text = (directory / name).read_text(encoding="utf-8")
                    self.assertIn("PRAXO-CORE (also written praxocore)", text)
                self.assertIn("agent framework", product_intro(entry))
        for relative in ("README.zh-CN.md", "docs/index.md", "docs/zh-CN/index.md", "llms.txt"):
            self.assertIn("praxocore", (ROOT / relative).read_text(encoding="utf-8").split("\n## ", 1)[0])

    def test_generated_introductions_are_ordered_and_evidence_scoped(self):
        for entry in registry.LANGUAGES:
            if entry["dir"] == ".":
                continue
            text = registry.render_registry(entry, ROOT / entry["dir"])
            headings = ("## Positioning", "## Package", "## Get Started", "## Examples, Tutorials, and Applications", "### Scenario tutorials", "### Reference applications", "## Boundaries", "## Community")
            positions = [text.index(heading) for heading in headings]
            with self.subTest(language=entry["name"]):
                self.assertEqual(positions, sorted(positions))
                self.assertIn("not end-to-end portfolio acceptance", text)
                self.assertIn("source_version", registry.manifest_data()[entry["name"]])
                self.assertIn("production", text)
                self.assertIn("verify", text.lower())
                self.assertIn("https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/", text)

    def test_readme_generation_is_idempotent_and_retains_content(self):
        entry = next(item for item in registry.LANGUAGES if item["name"] == "Python")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / "language/python"
            directory.mkdir(parents=True)
            readme = directory / "README.md"
            readme.write_text("# Python\n\nA native implementation.\n\n## Quickstart\n\nKeep this command.\n", encoding="utf-8")
            with patch.object(registry, "ROOT", root), patch.object(catalog, "ROOT", root):
                registry.insert_block(readme, entry)
                first = readme.read_text(encoding="utf-8")
                registry.insert_block(readme, entry)
                self.assertEqual(first, readme.read_text(encoding="utf-8"))
                self.assertEqual(first.count("also written praxocore"), 1)
                self.assertIn("A native implementation.", first)
                self.assertIn("Keep this command.", first)
                self.assertIn("no language-specific", first)

    def test_canonical_examples_and_shared_octave_links(self):
        self.assertIn("language/go/examples", catalog.examples_line(ROOT))
        self.assertIn("language/octave/examples", catalog.examples_line(ROOT / "language/octave"))
        self.assertNotIn("tree/main/examples", catalog.examples_line(ROOT))
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "language/matlab/examples").mkdir(parents=True)
            with patch.object(catalog, "ROOT", root):
                self.assertIn("language/matlab/examples", catalog.examples_line(root / "language/octave"))

    def test_mirror_introductions_include_alias_and_keep_source_scope(self):
        for entry in mirrors.mirror_entries():
            text = mirrors.mirror_readme(entry, has_examples=True)
            with self.subTest(language=entry["name"]):
                self.assertIn("praxocore", text.split("\n## ", 1)[0])
                headings = ("## Quick start", "## Examples", "## Scenario Tutorials", "## Reference Applications", "## Boundaries", "## Community")
                self.assertEqual([text.index(h) for h in headings], sorted(text.index(h) for h in headings))
                self.assertIn("not end-to-end portfolio acceptance", text)
                self.assertIn("does not publish mirror tags or registry packages", text)

    def test_catalog_does_not_truncate_evidence_boundaries(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / "language/java/application"
            directory.mkdir(parents=True)
            description = "A source-only reference application with bounded tool scope. " * 5
            description += "No live-provider validation or production acceptance is claimed."
            (directory / "README.md").write_text("# Application\n\n" + description + "\n", encoding="utf-8")
            entry = {"key": "java", "dir": "language/java"}
            self.assertEqual(catalog._catalog_entries(root, entry, "application")[0][2], description)

    def test_native_package_keywords_respect_ecosystem_rules(self):
        python = tomllib.loads((ROOT / "language/python/pyproject.toml").read_text(encoding="utf-8"))["project"]
        npm = json.loads((ROOT / "language/typescript/package.json").read_text(encoding="utf-8"))
        rust = tomllib.loads((ROOT / "language/rust/Cargo.toml").read_text(encoding="utf-8"))["package"]
        cs = ET.parse(ROOT / "language/csharp/Praxo.Core/Praxo.Core.csproj").getroot()
        for data in (python, npm, rust):
            self.assertIn("praxocore", data["description"])
            self.assertIn("praxocore", data["keywords"])
            self.assertIn("tool-calling", data["keywords"])
        self.assertIn("python", python["keywords"])
        self.assertTrue({"typescript", "javascript", "nodejs", "mcp", "opentelemetry"} <= set(npm["keywords"]))
        self.assertLessEqual(len(rust["keywords"]), 5)
        self.assertTrue(all(re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]{0,19}", word) for word in rust["keywords"]))
        self.assertIn("praxocore", cs.findtext("PropertyGroup/Description"))
        self.assertIn("dotnet", cs.findtext("PropertyGroup/PackageTags").split(";"))
        dart = (ROOT / "language/dart/pubspec.yaml").read_text(encoding="utf-8")
        topics = re.findall(r"^  - (.+)$", dart, re.M)
        self.assertEqual(len(topics), 5)
        self.assertIn("praxocore", topics)
        self.assertTrue(all(re.fullmatch(r"[a-z][a-z0-9-]{0,31}", word) for word in topics))

    def test_metadata_only_changes_do_not_rename_packages(self):
        python = tomllib.loads((ROOT / "language/python/pyproject.toml").read_text(encoding="utf-8"))["project"]
        npm = json.loads((ROOT / "language/typescript/package.json").read_text(encoding="utf-8"))
        rust = tomllib.loads((ROOT / "language/rust/Cargo.toml").read_text(encoding="utf-8"))["package"]
        self.assertEqual((python["name"], python["version"]), ("praxo-core", "0.11.2"))
        self.assertEqual((npm["name"], npm["version"]), ("@axisvela/praxo-core", "0.10.1"))
        self.assertEqual((rust["name"], rust["version"]), ("praxo-core", "0.11.1"))
        ET.parse(ROOT / "language/java/pom.xml")

    def test_application_catalog_keeps_direct_implementation_roots(self):
        for language in ("java", "rust", "cpp", "cobol", "elixir", "erlang", "julia", "ruby", "php"):
            with self.subTest(language=language):
                text = catalog.content_links(ROOT / "language" / language)
                self.assertIn(f"tree/main/language/{language}/application)", text)
                self.assertNotIn("No accepted end-to-end reference application is recorded", text)
                self.assertIn("not end-to-end portfolio acceptance", text)
        for language in ("python", "typescript", "csharp"):
            text = catalog.content_links(ROOT / "language" / language)
            self.assertIn("No accepted end-to-end reference application is recorded", text)

    def test_homepage_structured_identity_is_accurate_and_script_safe(self):
        config = {"site_url": "https://axisvela.github.io/praxo-core/", "site_description": "Framework </script><script>unsafe</script> & tools"}
        output = "<html><head></head><body>Home</body></html>"
        for uri in ("index.md", "zh-CN/index.md"):
            page = SimpleNamespace(file=SimpleNamespace(src_uri=uri))
            result = docs_hooks.on_post_page(output, page, config)
            payload = re.search(r'<script type="application/ld\+json">(.*?)</script>', result)[1]
            data = json.loads(payload)
            self.assertEqual(data["@type"], "SoftwareSourceCode")
            self.assertEqual(data["alternateName"], ["praxo-core", "praxocore"])
            self.assertEqual(data["codeRepository"], "https://github.com/axisvela/praxo-core")
            self.assertEqual(data["description"], config["site_description"])
            self.assertNotIn("<", payload)
            self.assertNotIn("&", payload)
            self.assertNotIn("aggregateRating", data)
        page = SimpleNamespace(file=SimpleNamespace(src_uri="languages/python/index.md"))
        self.assertEqual(docs_hooks.on_post_page(output, page, config), output)


if __name__ == "__main__":
    unittest.main()
