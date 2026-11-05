from html.parser import HTMLParser
import json
from pathlib import Path
import re
import tomllib
import unittest
import xml.etree.ElementTree as ElementTree
from types import SimpleNamespace
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
    def test_go_governed_acceptance_docs(self):
        source = (ROOT / "examples/consumer-go/governed_test.go").read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("func TestGoverned"), 5)
        for prefix, heading in (("", "Governed Acceptance"), ("zh-CN/", "治理验收")):
            page = (ROOT / "docs" / prefix / "getting-started/consumer-go.md").read_text(encoding="utf-8")
            self.assertIn(heading, page)
            self.assertIn("go test -mod=readonly -run Governed", page)

    def test_python_governed_acceptance_docs(self):
        source = (ROOT / "examples/consumer-python/test_governed.py").read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("async def test_"), 5)
        for prefix, heading in (("", "Governed Acceptance"), ("zh-CN/", "治理验收")):
            page = (ROOT / "docs" / prefix / "getting-started/consumer-python.md").read_text(encoding="utf-8")
            self.assertIn(heading, page)
            self.assertIn("test_governed.py", page)

    def test_typescript_governed_acceptance_docs(self):
        source = (ROOT / "examples/consumer-typescript/governed.test.js").read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count('test("'), 5)
        for prefix, heading in (("", "Governed Acceptance"), ("zh-CN/", "治理验收")):
            page = (ROOT / "docs" / prefix / "getting-started/consumer-typescript.md").read_text(encoding="utf-8")
            self.assertIn(heading, page)
            self.assertIn("governed.test.js", page)

    def test_contract_status_vocabulary_and_links(self):
        expectations = {
            "": ("Implemented", "Proposed", "Experimental", "Not run", "Not started"),
            "zh-CN/": ("已实现", "提案", "实验", "未运行", "未开始"),
        }
        for prefix, terms in expectations.items():
            page = (ROOT / "docs" / prefix / "project/contract-status.md").read_text(encoding="utf-8")
            for term in terms:
                self.assertIn(term, page)
            roadmap = (ROOT / "docs" / prefix / "project/roadmap.md").read_text(encoding="utf-8")
            self.assertIn("contract-status.md", roadmap)
        spec = (ROOT / "spec/README.md").read_text(encoding="utf-8")
        self.assertIn("does not by itself authorize a shared\n   wire addition", spec)
        policy = (ROOT / "docs/project/compatibility-policy.md").read_text(encoding="utf-8")
        self.assertIn("does not by itself authorize a\n  new field in shared `spec/wire/`", policy)
        chinese = (ROOT / "docs/zh-CN/project/compatibility-policy.md").read_text(encoding="utf-8")
        self.assertIn("不能单独授权", chinese)
        navigation = (ROOT / "mkdocs.yml").read_text(encoding="utf-8")
        self.assertIn("project/contract-status.md", navigation)

    def test_built_contract_status(self):
        for prefix in ("", "zh-CN/"):
            html = (ROOT / "site" / prefix / "project/contract-status/index.html").read_text(encoding="utf-8")
            parser = Links()
            parser.feed(html)
            text = "".join(parser.text)
            self.assertIn("Verified", text if not prefix else text)
            self.assertIn("Not run", text)

    def test_java_consumer_version_and_sources(self):
        namespace = {"m": "http://maven.apache.org/POM/4.0.0"}
        source = ElementTree.parse(ROOT / "language/java/pom.xml").getroot()
        version = source.find("m:version", namespace).text
        consumer = ElementTree.parse(ROOT / "examples/consumer-java/pom.xml").getroot()
        dependencies = [
            dependency for dependency in consumer.findall(".//m:dependency", namespace)
            if dependency.findtext("m:groupId", namespaces=namespace) == "com.axisvela"
            and dependency.findtext("m:artifactId", namespaces=namespace) == "praxo-core"
        ]
        self.assertEqual(len(dependencies), 1)
        self.assertEqual(dependencies[0].findtext("m:version", namespaces=namespace), version)
        page = SimpleNamespace(meta={})
        for filename in ("App.java", "AppTest.java"):
            marker = "<!-- java-consumer-source: " + filename + " -->"
            source_text = (ROOT / "examples/consumer-java/src" / ("main" if filename == "App.java" else "test")
                           / "java/starter" / filename).read_text(encoding="utf-8")
            self.assertEqual(docs_hooks.on_page_markdown(marker, page, None, None), "```java\n" + source_text.rstrip() + "\n```")
            for prefix in ("", "zh-CN/"):
                guide = (ROOT / "docs" / prefix / "getting-started/consumer-java.md").read_text(encoding="utf-8")
                self.assertIn(marker, guide)
                self.assertIn("<version>" + version + "</version>", guide)

    def test_built_java_consumer_source(self):
        for prefix in ("", "zh-CN/"):
            html = (ROOT / "site" / prefix / "getting-started/consumer-java/index.html").read_text(encoding="utf-8")
            parser = Links()
            parser.feed(html)
            text = "".join(parser.text)
            self.assertIn("static Built buildAgent(", text)
            self.assertIn("void deniedToolHasNoEffect(", text)
            self.assertNotIn("java-consumer-source:", html)

    def test_typescript_consumer_version_and_sources(self):
        metadata = json.loads((ROOT / "language/typescript/package.json").read_text(encoding="utf-8"))
        version = metadata["version"]
        package = json.loads((ROOT / "examples/consumer-typescript/package.json").read_text(encoding="utf-8"))
        lockfile = json.loads((ROOT / "examples/consumer-typescript/package-lock.json").read_text(encoding="utf-8"))
        self.assertEqual(package["dependencies"]["@axisvela/praxo-core"], version)
        self.assertEqual(lockfile["packages"][""]["dependencies"]["@axisvela/praxo-core"], version)
        self.assertEqual(lockfile["packages"]["node_modules/@axisvela/praxo-core"]["version"], version)
        page = SimpleNamespace(meta={})
        for filename in ("starter.js", "test_starter.test.js"):
            marker = "<!-- typescript-consumer-source: " + filename + " -->"
            source = (ROOT / "examples/consumer-typescript" / filename).read_text(encoding="utf-8")
            self.assertEqual(docs_hooks.on_page_markdown(marker, page, None, None), "```javascript\n" + source.rstrip() + "\n```")
            for prefix in ("", "zh-CN/"):
                guide = (ROOT / "docs" / prefix / "getting-started/consumer-typescript.md").read_text(encoding="utf-8")
                self.assertIn(marker, guide)
                self.assertIn("@axisvela/praxo-core@" + version, guide)

    def test_built_typescript_consumer_source(self):
        for prefix in ("", "zh-CN/"):
            html = (ROOT / "site" / prefix / "getting-started/consumer-typescript/index.html").read_text(encoding="utf-8")
            parser = Links()
            parser.feed(html)
            text = "".join(parser.text)
            self.assertIn("function buildAgent(", text)
            self.assertIn('test("denied tool has no effect"', text)
            self.assertNotIn("typescript-consumer-source:", html)

    def test_python_consumer_version_and_sources(self):
        metadata = tomllib.loads((ROOT / "language/python/pyproject.toml").read_text(encoding="utf-8"))
        version = metadata["project"]["version"]
        requirement = "praxo-core==" + version
        self.assertEqual((ROOT / "examples/consumer-python/requirements.txt").read_text().strip(), requirement)
        page = SimpleNamespace(meta={})
        for filename in ("starter.py", "test_starter.py"):
            marker = "<!-- python-consumer-source: " + filename + " -->"
            source = (ROOT / "examples/consumer-python" / filename).read_text(encoding="utf-8")
            self.assertEqual(docs_hooks.on_page_markdown(marker, page, None, None), "```python\n" + source.rstrip() + "\n```")
            for prefix in ("", "zh-CN/"):
                guide = (ROOT / "docs" / prefix / "getting-started/consumer-python.md").read_text(encoding="utf-8")
                self.assertIn(marker, guide)
                self.assertIn(requirement, guide)

    def test_built_python_consumer_source(self):
        for prefix in ("", "zh-CN/"):
            html = (ROOT / "site" / prefix / "getting-started/consumer-python/index.html").read_text(encoding="utf-8")
            parser = Links()
            parser.feed(html)
            text = "".join(parser.text)
            self.assertIn("def build_agent(", text)
            self.assertIn("def test_denied_tool_has_no_effect(", text)
            self.assertNotIn("python-consumer-source:", html)

    def test_consumer_version_matches_recommended_release(self):
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        module = (ROOT / "examples/consumer-go/go.mod").read_text(encoding="utf-8")
        self.assertIn("require github.com/axisvela/praxo-core/v2 v" + version + "\n", module)
        for prefix in ("", "zh-CN/"):
            guide = (ROOT / "docs" / prefix / "getting-started/consumer-go.md").read_text(encoding="utf-8")
            self.assertIn("go get github.com/axisvela/praxo-core/v2@v" + version, guide)

    def test_consumer_source_uses_tested_files(self):
        page = SimpleNamespace(meta={})
        for filename in ("main.go", "main_test.go"):
            marker = "<!-- go-consumer-source: " + filename + " -->"
            source = (ROOT / "examples/consumer-go" / filename).read_text(encoding="utf-8")
            rendered = docs_hooks.on_page_markdown(marker, page, None, None)
            self.assertEqual(rendered, "```go\n" + source.rstrip() + "\n```")
            for prefix in ("", "zh-CN/"):
                text = (ROOT / "docs" / prefix / "getting-started/consumer-go.md").read_text(encoding="utf-8")
                self.assertIn(marker, text)

    def test_built_consumer_source(self):
        for prefix in ("", "zh-CN/"):
            html = (ROOT / "site" / prefix / "getting-started/consumer-go/index.html").read_text(encoding="utf-8")
            parser = Links()
            parser.feed(html)
            text = "".join(parser.text)
            self.assertIn("func runScenario(", text)
            self.assertIn("func TestDeniedToolHasNoEffect(", text)
            self.assertNotIn("go-consumer-source:", html)

    def test_sdk_readme_links(self):
        text = "[API](API.md) [spec](../../spec/README.md#wire) [anchor](#usage) [web](https://example.com/)"
        result = docs_hooks.sdk_readme(text, "language/python/README.md")
        self.assertIn(docs_hooks.REPOSITORY + "language/python/API.md", result)
        self.assertIn(docs_hooks.REPOSITORY + "spec/README.md#wire", result)
        self.assertIn("[anchor](#usage)", result)
        self.assertIn("[web](https://example.com/)", result)

    def test_sdk_sources_exist(self):
        pages = list((ROOT / "docs/languages").glob("*/index.md"))
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
        for page in docs_hooks.MOVED_LANGUAGE_PAGES:
            if page in ("index", "support"):
                self.assertTrue((ROOT / "docs/languages" / (page + ".md")).is_file())
            else:
                self.assertTrue((ROOT / "docs/languages" / page / "index.md").is_file())
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
        for row in source_rows:
            name, _, _, tag, _, notes = [cell.strip() for cell in row.strip("| ").split("|")]
            self.assertIn(name, english)
            self.assertIn(name, chinese)
            if tag != "none":
                self.assertIn(tag, english)
                self.assertIn(tag, chinese)
            self.assertIn(notes, english)

    def test_language_matrix_fixture(self):
        source = """## Matrix
| Language | Tier | Status | Tag | Maturity | Notes |
| --- | --- | --- | --- | --- | --- |
| Python | Core | released | `python/v9.8.7` | complete | fixture scope |
| MATLAB | Core | released | `matlab/v9.8.7` | partial | runtime unverified |
| Future | Bridge | planned | none | planned | consumer required |
"""
        self.assertIn("[Python](python/index.md) | Framework (Core) | released | `python/v9.8.7` | complete | fixture scope", docs_hooks.language_matrix(source))
        chinese = docs_hooks.language_matrix(source, chinese=True)
        self.assertIn("[MATLAB](matlab/index.md) | Framework (Core) | 源码已发布 | `matlab/v9.8.7` | 部分完成", chinese)
        self.assertIn("Future | Bridge | 计划中 | — | 计划中 | consumer required", chinese)
        for invalid in (source.replace("| planned | none", "| unknown | none"),
                        source + source.splitlines()[3] + "\n",
                        source.replace("| Core |", "| Unknown |"),
                        source.replace("| partial |", "| unknown |"),
                        source.replace("| fixture scope", "| extra | fixture scope"),
                        "## Matrix\n"):
            with self.subTest(source=invalid), self.assertRaises(ValueError):
                docs_hooks.language_matrix(invalid)

    def test_built_language_matrix(self):
        source = (ROOT / "spec/languages.md").read_text(encoding="utf-8")
        section = source.split("## Matrix\n", 1)[1].split("\n## ", 1)[0]
        rows = [line for line in section.splitlines() if line.startswith("| ")][2:]
        for prefix in ("", "zh-CN/"):
            html = (ROOT / "site" / prefix / "languages/matrix/index.html").read_text(encoding="utf-8")
            parser = Links()
            parser.feed(html)
            text = "".join(parser.text)
            for row in rows:
                name, _, _, tag, _, _ = [cell.strip() for cell in row.strip("| ").split("|")]
                self.assertIn(name, text)
                if tag != "none":
                    self.assertIn(tag.strip("`"), text)
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
