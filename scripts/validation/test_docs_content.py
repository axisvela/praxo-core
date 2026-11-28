from .docs_test_support import *


class DocumentationContentTests(unittest.TestCase):
    def test_current_scoped_java_and_php_evidence(self):
        for prefix in ("", "zh-CN/"):
            with self.subTest(language=prefix):
                evidence = (ROOT / "docs" / prefix / "project/verification-evidence.md").read_text(encoding="utf-8")
                for value in ("46018135957", "b531f6abdfc1775ce5122357c496d834428cfe63",
                              "46026595266", "02e736e4a57895dffafab51a8be85dbc9c9d9601",
                              "java-ai-commerce", "java-new-tutorials", "airport-recovery",
                              "CANCELLED", "2026-11-28"):
                    self.assertIn(value, evidence)
                status = (ROOT / "docs" / prefix / "languages/registry-status.md").read_text(encoding="utf-8")
                for value in ("0.10.1", "0.10.2", "src/PluginProcessHost.php", "46030983730", "166", "ff9d2fe"):
                    self.assertIn(value, status)

    def test_go_governed_acceptance_docs(self):
        source = (ROOT / "language/go/examples/consumer-go/governed_test.go").read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("func TestGoverned"), 5)
        for prefix, heading in (("", "Governed Acceptance"), ("zh-CN/", "治理验收")):
            page = (ROOT / "docs" / prefix / "getting-started/consumer-go.md").read_text(encoding="utf-8")
            self.assertIn(heading, page)
            self.assertIn("go test -mod=readonly -run Governed", page)

    def test_python_governed_acceptance_docs(self):
        source = (ROOT / "language/python/examples/consumer/test_governed.py").read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("async def test_"), 5)
        for prefix, heading in (("", "Governed Acceptance"), ("zh-CN/", "治理验收")):
            page = (ROOT / "docs" / prefix / "getting-started/consumer-python.md").read_text(encoding="utf-8")
            self.assertIn(heading, page)
            self.assertIn("test_governed.py", page)

    def test_typescript_governed_acceptance_docs(self):
        source = (ROOT / "language/typescript/examples/consumer/governed.test.js").read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count('test("'), 5)
        for prefix, heading in (("", "Governed Acceptance"), ("zh-CN/", "治理验收")):
            page = (ROOT / "docs" / prefix / "getting-started/consumer-typescript.md").read_text(encoding="utf-8")
            self.assertIn(heading, page)
            self.assertIn("governed.test.js", page)

    def test_java_governed_acceptance_docs(self):
        source = (ROOT / "language/java/examples/consumer/src/test/java/starter/GovernedAcceptanceTest.java").read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("@Test"), 5)
        for prefix, heading in (("", "Governed Acceptance"), ("zh-CN/", "治理验收")):
            page = (ROOT / "docs" / prefix / "getting-started/consumer-java.md").read_text(encoding="utf-8")
            self.assertIn(heading, page)
            self.assertIn("GovernedAcceptanceTest", page)

    def test_agent_integration_map(self):
        data = json.loads((ROOT / "docs/getting-started/agent-integration.json").read_text(encoding="utf-8"))
        spec_version = (ROOT / "spec/SPEC_VERSION").read_text(encoding="utf-8").strip()
        self.assertEqual(data["specVersion"], spec_version)
        entries = {entry["language"]: entry for entry in data["languages"]}
        self.assertEqual(
            set(entries),
            {"Go", "Python", "TypeScript", "Java", "Ruby", "PHP", "Elixir", "Lua",
             "C#", "Rust", "R"},
        )
        registry = json.loads((ROOT / "language/registry-metadata.json").read_text(encoding="utf-8"))
        go_version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        python_version = tomllib.loads((ROOT / "language/python/pyproject.toml").read_text(encoding="utf-8"))["project"]["version"]
        ts_version = json.loads((ROOT / "language/typescript/package.json").read_text(encoding="utf-8"))["version"]
        java_version = ElementTree.parse(ROOT / "language/java/pom.xml").getroot().find(
            "m:version", {"m": "http://maven.apache.org/POM/4.0.0"}).text
        self.assertEqual(registry["Go"]["source_version"].lstrip("v"), go_version)
        self.assertEqual(registry["Python"]["source_version"], python_version)
        self.assertEqual(registry["TypeScript"]["source_version"], ts_version)
        self.assertEqual(registry["Java"]["source_version"], java_version)
        self.assertEqual(entries["Go"]["version"], registry["Go"]["published_version"].lstrip("v"))
        self.assertEqual(entries["Python"]["version"], registry["Python"]["published_version"])
        self.assertEqual(entries["TypeScript"]["version"], registry["TypeScript"]["published_version"])
        self.assertEqual(entries["Java"]["version"], registry["Java"]["published_version"])
        for language in ("Ruby", "PHP", "Elixir", "Lua"):
            self.assertEqual(entries[language]["version"], registry[language]["published_version"])
        for entry in entries.values():
            self.assertTrue((ROOT / entry["starter"]).is_dir(), entry["starter"])
            self.assertTrue((ROOT / entry["guide"]).is_file(), entry["guide"])
            self.assertTrue(entry["registry"], entry["language"])
            self.assertTrue(entry["registryPage"].startswith("https://"), entry["language"])
        for prefix in ("", "zh-CN/"):
            page = (ROOT / "docs" / prefix / "getting-started/coding-agents.md").read_text(encoding="utf-8")
            self.assertIn("agent-integration.json", page)
            self.assertIn(entries["Go"]["version"], page)
            for entry in entries.values():
                self.assertIn(f"`{entry['package']}`", page, entry["language"])
                self.assertIn(f"`{entry['version']}`", page, entry["language"])
        self.assertIn("getting-started/coding-agents.md", (ROOT / "mkdocs.yml").read_text(encoding="utf-8"))
        self.assertTrue((ROOT / "site/getting-started/agent-integration.json").is_file())

    def test_perl_pod_classification(self):
        source = (ROOT / "language/perl/lib/Praxo/Core.pm").read_text(encoding="utf-8")
        self.assertIn("=head1 NAME", source)
        self.assertIn("Embeddable AI agent framework for Perl", source)
        self.assertIn("not an HTTP user agent", source)
        makefile = (ROOT / "language/perl/Makefile.PL").read_text(encoding="utf-8")
        self.assertIn("Embeddable AI agent framework", makefile)

    def test_registry_page_metadata(self):
        python_meta = tomllib.loads((ROOT / "language/python/pyproject.toml").read_text(encoding="utf-8"))
        self.assertIn("human-in-the-loop", python_meta["project"]["description"])
        self.assertIn("tool-authorization", python_meta["project"]["keywords"])
        ts_meta = json.loads((ROOT / "language/typescript/package.json").read_text(encoding="utf-8"))
        self.assertIn("human-in-the-loop", ts_meta["description"])
        self.assertIn("tool-authorization", ts_meta["keywords"])
        java_meta = ElementTree.parse(ROOT / "language/java/pom.xml").getroot()
        java_description = java_meta.findtext("m:description", namespaces={"m": "http://maven.apache.org/POM/4.0.0"})
        self.assertIn("human-in-the-loop", java_description)
        self.assertIn("checkpoints", java_description)
        for readme in (
            "language/python/README.md",
            "language/typescript/README.md",
            "language/java/README.md",
        ):
            self.assertIn("consumer", (ROOT / readme).read_text(encoding="utf-8").lower())
        for prefix, snapshot_word in (("", "snapshot"), ("zh-CN/", "快照")):
            page = (ROOT / "docs" / prefix / "languages/registry-pages.md").read_text(encoding="utf-8")
            self.assertIn(snapshot_word, page)
            status = (ROOT / "docs" / prefix / "languages/registry-status.md").read_text(encoding="utf-8")
            self.assertIn("registry-pages.md", status)
        self.assertIn("languages/registry-pages.md", (ROOT / "mkdocs.yml").read_text(encoding="utf-8"))
        self.assertTrue((ROOT / "site/languages/registry-pages/index.html").is_file())

    def test_identity_policy_recipe(self):
        source = (ROOT / "language/go/examples/recipes/identity-go/identity_test.go").read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("func TestIdentity"), 5)
        for prefix, phrase in (("", "verified principal"), ("zh-CN/", "已验证 principal")):
            page = (ROOT / "docs" / prefix / "guides/identity-policy.md").read_text(encoding="utf-8")
            self.assertIn(phrase, page)
            self.assertIn("recipes/identity-go", page)
        self.assertIn("guides/identity-policy.md", (ROOT / "mkdocs.yml").read_text(encoding="utf-8"))
        self.assertTrue((ROOT / "site/guides/identity-policy/index.html").is_file())

    def test_agent_skill_template(self):
        skill = (ROOT / "agent-skills/praxo-integration/SKILL.md").read_text(encoding="utf-8")
        self.assertTrue(skill.startswith("---\nname: praxo-integration\ndescription:"))
        self.assertIn("docs/getting-started/agent-integration.json", skill)
        self.assertIn("exactly-once", skill)
        readme = (ROOT / "agent-skills/praxo-integration/README.md").read_text(encoding="utf-8")
        self.assertIn("not an automatically installed", readme)
        self.assertIn("does not guarantee", readme)
        for prefix in ("", "zh-CN/"):
            page = (ROOT / "docs" / prefix / "getting-started/coding-agents.md").read_text(encoding="utf-8")
            self.assertIn("agent-skills/praxo-integration", page)
        self.assertIn("skill template", (ROOT / "docs/project/contract-status.md").read_text(encoding="utf-8"))
        self.assertIn("Skill 模板", (ROOT / "docs/zh-CN/project/contract-status.md").read_text(encoding="utf-8"))

    def test_long_running_recipe(self):
        recipe = ROOT / "language/go/examples/recipes/long-running-go"
        source = (recipe / "longrunning_test.go").read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("func TestLongRunning"), 7)
        self.assertIn("TestLongRunningSurvivesRestart", source)
        self.assertIn("TestLongRunningCompletionIsNotEffectVerification", source)
        http_source = (recipe / "longrunning_http_test.go").read_text(encoding="utf-8")
        self.assertIn("TestLongRunningHTTPResponseLossAndRestart", http_source)
        self.assertIn("TestLongRunningHTTPRequiresBearerToken", http_source)
        self.assertIn("TestLongRunningHTTPCancelAndEffectEvidence", http_source)
        self.assertIn("receipt", http_source)
        process_source = (recipe / "longrunning_process_test.go").read_text(encoding="utf-8")
        self.assertIn("TestLongRunningCrossProcessRestart", process_source)
        self.assertIn("TestLongRunningPartialWriteDoesNotCorruptState", source)
        fence_source = (recipe / "longrunning_fence_test.go").read_text(encoding="utf-8")
        self.assertIn("TestLongRunningFencingRejectsStaleWorker", fence_source)
        self.assertIn("TestLongRunningIndependentVerifier", process_source)
        self.assertIn("TestLongRunningDurableFencingAfterRestart", fence_source)
        page = (ROOT / "docs/guides/long-running-operations.md").read_text(encoding="utf-8")
        self.assertIn("verifier-issued receipt", page)
        self.assertIn("Cross-process restart", page)
        self.assertIn("language/go/examples/recipes/long-running-go", page)
        for prefix, phrase in (("", "Run canceled"), ("zh-CN/", "Run 取消")):
            page = (ROOT / "docs" / prefix / "guides/long-running-operations.md").read_text(encoding="utf-8")
            self.assertIn(phrase, page)
            self.assertIn("recipes/long-running-go", page)
        self.assertIn("guides/long-running-operations.md", (ROOT / "mkdocs.yml").read_text(encoding="utf-8"))
        self.assertTrue((ROOT / "site/guides/long-running-operations/index.html").is_file())

    def test_test_taxonomy_and_consumer_map(self):
        for prefix, terms in (
            ("", ("L1 Core contract", "L4 Application recipe", "Do not internalize")),
            ("zh-CN/", ("L1 Core", "L4 应用配方", "不要仅因配方测试通过就内化")),
        ):
            page = (ROOT / "docs" / prefix / "project/test-taxonomy.md").read_text(encoding="utf-8")
            for term in terms:
                self.assertIn(term, page)
            self.assertIn("test-taxonomy.md", (ROOT / "docs" / prefix / "project/contract-status.md").read_text(encoding="utf-8"))
        self.assertIn("consumer-go", (ROOT / "docs/project/test-taxonomy.md").read_text(encoding="utf-8"))
        self.assertIn("test-taxonomy.md", (ROOT / "language/go/examples/consumer-go/README.md").read_text(encoding="utf-8"))
        self.assertIn("project/test-taxonomy.md", (ROOT / "mkdocs.yml").read_text(encoding="utf-8"))
        self.assertTrue((ROOT / "site/project/test-taxonomy/index.html").is_file())

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

