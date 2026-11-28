from .docs_test_support import *


class ConsumerDocumentationTests(unittest.TestCase):
    def test_java_consumer_version_and_sources(self):
        namespace = {"m": "http://maven.apache.org/POM/4.0.0"}
        source = ElementTree.parse(ROOT / "language/java/pom.xml").getroot()
        source_version = source.find("m:version", namespace).text
        registry = json.loads((ROOT / "language/registry-metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(registry["Java"]["source_version"], source_version)
        version = registry["Java"]["published_version"]
        consumer = ElementTree.parse(ROOT / "language/java/examples/consumer/pom.xml").getroot()
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
            source_text = (ROOT / "language/java/examples/consumer/src" / ("main" if filename == "App.java" else "test")
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
        registry = json.loads((ROOT / "language/registry-metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(registry["TypeScript"]["source_version"], metadata["version"])
        version = registry["TypeScript"]["published_version"]
        package = json.loads((ROOT / "language/typescript/examples/consumer/package.json").read_text(encoding="utf-8"))
        lockfile = json.loads((ROOT / "language/typescript/examples/consumer/package-lock.json").read_text(encoding="utf-8"))
        self.assertEqual(package["dependencies"]["@axisvela/praxo-core"], version)
        self.assertEqual(lockfile["packages"][""]["dependencies"]["@axisvela/praxo-core"], version)
        self.assertEqual(lockfile["packages"]["node_modules/@axisvela/praxo-core"]["version"], version)
        page = SimpleNamespace(meta={})
        for filename in ("starter.js", "test_starter.test.js"):
            marker = "<!-- typescript-consumer-source: " + filename + " -->"
            source = (ROOT / "language/typescript/examples/consumer" / filename).read_text(encoding="utf-8")
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
        registry = json.loads((ROOT / "language/registry-metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(registry["Python"]["source_version"], metadata["project"]["version"])
        version = registry["Python"]["published_version"]
        requirement = "praxo-core==" + version
        self.assertEqual((ROOT / "language/python/examples/consumer/requirements.txt").read_text().strip(), requirement)
        page = SimpleNamespace(meta={})
        for filename in ("starter.py", "test_starter.py"):
            marker = "<!-- python-consumer-source: " + filename + " -->"
            source = (ROOT / "language/python/examples/consumer" / filename).read_text(encoding="utf-8")
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
        module = (ROOT / "language/go/examples/consumer-go/go.mod").read_text(encoding="utf-8")
        self.assertIn("require github.com/axisvela/praxo-core/v2 v" + version + "\n", module)
        for prefix in ("", "zh-CN/"):
            guide = (ROOT / "docs" / prefix / "getting-started/consumer-go.md").read_text(encoding="utf-8")
            self.assertIn("go get github.com/axisvela/praxo-core/v2@v" + version, guide)

    def test_consumer_source_uses_tested_files(self):
        page = SimpleNamespace(meta={})
        for filename in ("main.go", "main_test.go"):
            marker = "<!-- go-consumer-source: " + filename + " -->"
            source = (ROOT / "language/go/examples/consumer-go" / filename).read_text(encoding="utf-8")
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

