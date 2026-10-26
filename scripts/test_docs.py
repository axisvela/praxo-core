from html.parser import HTMLParser
from pathlib import Path
import re
import unittest
from urllib.parse import unquote, urlsplit

import yaml

import docs_hooks


ROOT = docs_hooks.ROOT


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.targets = []
        self.alternates = []
        self.text = []

    def handle_data(self, data):
        self.text.append(data)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a" and "href" in attrs:
            self.targets.append(attrs["href"])
        if tag == "link" and attrs.get("rel") == "alternate":
            self.alternates.append(attrs)


class DocumentationTests(unittest.TestCase):
    def test_sdk_readme_links(self):
        text = "[API](API.md) [spec](../../spec/README.md#wire) [anchor](#usage) [web](https://example.com/)"
        result = docs_hooks.sdk_readme(text, "sdk/python/README.md")
        self.assertIn(docs_hooks.REPOSITORY + "sdk/python/API.md", result)
        self.assertIn(docs_hooks.REPOSITORY + "spec/README.md#wire", result)
        self.assertIn("[anchor](#usage)", result)
        self.assertIn("[web](https://example.com/)", result)

    def test_sdk_sources_exist(self):
        pages = list((ROOT / "docs/sdks").glob("*.md"))
        for page in pages:
            text = page.read_text(encoding="utf-8")
            if not text.startswith("---\n"):
                continue
            meta = yaml.safe_load(text.split("---", 2)[1])
            source = meta.get("sdk_readme")
            if source:
                self.assertTrue((ROOT / source).is_file(), source)
        self.assertEqual(len(pages), 28)

    def test_redirect_targets_exist(self):
        for old, new in docs_hooks.LEGACY_PATHS.items():
            self.assertFalse((ROOT / "docs" / old).exists(), old)
            self.assertTrue((ROOT / "docs" / new).exists(), new)

    def test_repository_document_links(self):
        sources = list((ROOT / "docs").rglob("*.md"))
        sources += list((ROOT / "spec").rglob("*.md"))
        sources += [ROOT / name / "README.md" for name in ("sdk", "bindings")]
        sources += list((ROOT / "sdk").glob("*/README.md"))
        sources += list((ROOT / "bindings").glob("*/README.md"))
        sources += [ROOT / "examples" / name / "README.md" for name in ("javascript", "kotlin", "scala")]
        sources += [ROOT / name for name in ("README.md", "README.zh-CN.md", "CONTRIBUTING.md", "SECURITY.md", "ROADMAP.md")]
        for source in sources:
            for target in re.findall(r"!?\[[^\]\n]*\]\(([^\s)]+)", source.read_text(encoding="utf-8")):
                parts = urlsplit(target)
                if parts.scheme or parts.netloc or not parts.path.endswith(".md"):
                    continue
                path = source.parent / unquote(parts.path)
                if not path.is_file() and path.resolve().is_relative_to(ROOT / "docs/zh-CN"):
                    path = ROOT / "docs" / path.resolve().relative_to(ROOT / "docs/zh-CN")
                self.assertTrue(path.is_file(), f"{source.relative_to(ROOT)} -> {target}")

    def test_navigation_is_two_levels(self):
        config = yaml.safe_load((ROOT / "mkdocs.yml").read_text(encoding="utf-8"))
        self.assertNotIn("navigation.sections", config["theme"]["features"])
        self.assertNotIn("navigation.expand", config["theme"]["features"])
        for item in config["nav"]:
            for target in item.values():
                if isinstance(target, list):
                    for child in target:
                        self.assertTrue(all(isinstance(value, str) for value in child.values()))
        releases = next(item["Releases"] for item in config["nav"] if "Releases" in item)
        self.assertEqual(len(releases), 3)

    def test_built_legacy_redirects(self):
        for prefix in ("", "zh-CN/"):
            for old, new in docs_hooks.LEGACY_PATHS.items():
                if prefix and not (ROOT / "docs" / prefix / new).exists():
                    continue
                redirect = ROOT / "site" / prefix / old.removesuffix(".md") / "index.html"
                self.assertTrue(redirect.is_file(), str(redirect))
                self.assertIn('http-equiv="refresh"', redirect.read_text(encoding="utf-8"))

    def test_built_local_links(self):
        site = ROOT / "site"
        self.assertTrue((site / "index.html").is_file(), "Run mkdocs build --strict first")
        for path in site.rglob("*.html"):
            parser = Links()
            parser.feed(path.read_text(encoding="utf-8"))
            for link in parser.targets:
                parts = urlsplit(link)
                if parts.scheme or parts.netloc or not parts.path:
                    continue
                if parts.path.startswith("/"):
                    local = parts.path.removeprefix("/praxo-core/").lstrip("/")
                    target = site / unquote(local)
                else:
                    target = path.parent / unquote(parts.path)
                self.assertTrue(target.exists(), f"{path.relative_to(site)} -> {link}")

    def test_bilingual_home_and_sdk_content(self):
        for prefix in ("", "zh-CN/"):
            home = (ROOT / "site" / prefix / "index.html").read_text(encoding="utf-8")
            parser = Links()
            parser.feed(home)
            self.assertTrue(any(item.get("hreflang") == "en" for item in parser.alternates))
            self.assertTrue(any(item.get("hreflang") == "zh-CN" for item in parser.alternates))
            self.assertIn('name="viewport"', home)
            sdk = (ROOT / "site" / prefix / "sdks/python/index.html").read_text(encoding="utf-8")
            content = Links()
            content.feed(sdk)
            self.assertIn("pip install", "".join(content.text))
            self.assertIn("Contract Surface", sdk)
            self.assertIn(docs_hooks.REPOSITORY + "sdk/python/API.md", sdk)


if __name__ == "__main__":
    unittest.main()
