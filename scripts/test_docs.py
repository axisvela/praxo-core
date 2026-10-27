from html.parser import HTMLParser
from pathlib import Path
import re
import unittest
from urllib.parse import unquote, urljoin, urlsplit

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
        result = docs_hooks.sdk_readme(text, "language/python/README.md")
        self.assertIn(docs_hooks.REPOSITORY + "language/python/API.md", result)
        self.assertIn(docs_hooks.REPOSITORY + "spec/README.md#wire", result)
        self.assertIn("[anchor](#usage)", result)
        self.assertIn("[web](https://example.com/)", result)

    def test_sdk_sources_exist(self):
        pages = list((ROOT / "docs/languages").glob("*.md"))
        for page in pages:
            text = page.read_text(encoding="utf-8")
            if not text.startswith("---\n"):
                continue
            meta = yaml.safe_load(text.split("---", 2)[1])
            source = meta.get("sdk_readme")
            if source:
                self.assertTrue((ROOT / source).is_file(), source)
        self.assertGreaterEqual(len(pages), 28)

    def test_redirect_targets_exist(self):
        for old, new in docs_hooks.LEGACY_PATHS.items():
            self.assertFalse((ROOT / "docs" / old).exists(), old)
            self.assertTrue((ROOT / "docs" / new).exists(), new)

    def test_moved_language_redirects_cover_all_pages(self):
        pages = {path.name for path in (ROOT / "docs/languages").glob("*.md")}
        self.assertTrue({page + ".md" for page in docs_hooks.MOVED_LANGUAGE_PAGES}.issubset(pages))
        for prefix in ("", "zh-CN/"):
            self.assertFalse((ROOT / "docs" / prefix / "sdks").exists())

    def test_repository_document_links(self):
        sources = list((ROOT / "docs").rglob("*.md"))
        sources += list((ROOT / "spec").rglob("*.md"))
        sources += [ROOT / name / "README.md" for name in ("language", "bindings")]
        sources += list((ROOT / "language").glob("*/README.md"))
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
        languages = next(item["Language Implementations"] for item in config["nav"] if "Language Implementations" in item)
        self.assertEqual(languages[0], {"Implementation Directory": "languages/index.md"})
        locales = config["plugins"][1]["i18n"]["languages"]
        chinese = next(locale for locale in locales if locale["locale"] == "zh-CN")
        self.assertEqual(chinese["nav_translations"]["Language Implementations"], "语言实现")

    def test_language_matrix_is_derived_from_canonical_source(self):
        source = (ROOT / "spec/languages.md").read_text(encoding="utf-8")
        english = docs_hooks.language_matrix(source)
        chinese = docs_hooks.language_matrix(source, chinese=True)
        matrix_section = source.split("## Matrix\n", 1)[1].split("\n## ", 1)[0]
        source_rows = [line for line in matrix_section.splitlines() if line.startswith("| ")][2:]
        self.assertEqual(english.count("\n| ") - 1, len(source_rows))
        self.assertIn("| Maturity |", english)
        self.assertIn("[Python](python.md) | Framework (Core) | released | `python/v0.2.0` | complete", english)
        self.assertIn("[MATLAB](matlab.md) | Framework (Core) | released | `matlab/v0.2.0` | complete", english)
        self.assertIn("[MATLAB](matlab.md) | Framework (Core) | 源码已发布 | `matlab/v0.2.0` | 完整", chinese)
        self.assertIn("[Haskell](haskell.md)", chinese)
        self.assertIn("public API is wire-level", english)
        with self.assertRaises(ValueError):
            docs_hooks.language_matrix(source.replace("| Haskell | Wire |", "| Haskell | Unknown |"))

    def test_built_language_matrix(self):
        for prefix in ("", "zh-CN/"):
            html = (ROOT / "site" / prefix / "languages/matrix/index.html").read_text(encoding="utf-8")
            self.assertIn("MATLAB", html)
            self.assertIn("Haskell", html)
            self.assertIn("python/v0.2.0", html)
            self.assertNotIn("&lt;!-- language-support-matrix --&gt;", html)

    def test_built_legacy_redirects(self):
        for prefix in ("", "zh-CN/"):
            for old, new in docs_hooks.LEGACY_PATHS.items():
                if prefix and not old.startswith("sdks/") and not (ROOT / "docs" / prefix / new).exists():
                    continue
                redirect = ROOT / "site" / prefix / old.removesuffix(".md")
                redirect = redirect.with_suffix(".html") if old.endswith("/index.md") else redirect / "index.html"
                self.assertTrue(redirect.is_file(), str(redirect))
                html = redirect.read_text(encoding="utf-8")
                self.assertIn('http-equiv="refresh"', html)
                if old.startswith("sdks/"):
                    target = re.search(r'url=([^"\s]+)', html, re.IGNORECASE)
                    self.assertIsNotNone(target, str(redirect))
                    resolved = urljoin(redirect.relative_to(ROOT / "site").as_posix(), target.group(1))
                    if urlsplit(resolved).netloc:
                        resolved = urlsplit(resolved).path.removeprefix("/praxo-core/")
                    expected = prefix + new.removesuffix(".md")
                    expected = expected.removesuffix("/index") + "/" if new.endswith("/index.md") else expected + "/"
                    self.assertEqual(resolved, expected)
                    self.assertTrue((ROOT / "site" / resolved / "index.html").is_file(), resolved)

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
            sdk = (ROOT / "site" / prefix / "languages/python/index.html").read_text(encoding="utf-8")
            content = Links()
            content.feed(sdk)
            self.assertIn("pip install", "".join(content.text))
            self.assertIn("Contract Surface", sdk)
            self.assertIn(docs_hooks.REPOSITORY + "language/python/API.md", sdk)


if __name__ == "__main__":
    unittest.main()
