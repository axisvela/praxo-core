import json
from pathlib import Path
import tempfile
import unittest

import check_consumer_pins as check


class ConsumerPinTests(unittest.TestCase):
    def build(
        self,
        go="2.7.0",
        python="0.3.2",
        typescript="0.2.2",
        java="0.4.1",
        ruby="0.4.1",
        php="0.4.0",
        elixir="0.4.0",
        lua="0.4.0-1",
        csharp="0.8.0",
        rust="0.8.0",
    ):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        for path in (
            root / "docs/getting-started",
            root / "language/go/examples/consumer-go",
            root / "language/python/examples/consumer",
            root / "language/typescript/examples/consumer",
            root / "language/java/examples/consumer",
            root / "language/ruby/examples/consumer",
            root / "language/php/examples/consumer",
            root / "language/elixir/examples/consumer",
            root / "language/lua/examples/consumer",
            root / "language/java/examples/consumer/src/test/java/starter",
            root / "language/csharp/examples/foo",
            root / "language/rust/examples/foo",
        ):
            path.mkdir(parents=True)
        (root / "VERSION").write_text("2.7.0\n", encoding="utf-8")
        (root / "docs/getting-started/agent-integration.json").write_text(
            json.dumps(
                {
                    "languages": [
                        {"language": "Go", "version": go},
                        {"language": "Python", "version": python},
                        {"language": "TypeScript", "version": typescript},
                        {"language": "Java", "version": java},
                        {"language": "Ruby", "version": ruby},
                        {"language": "PHP", "version": php},
                        {"language": "Elixir", "version": elixir},
                        {"language": "Lua", "version": lua},
                    ]
                }
            ),
            encoding="utf-8",
        )
        (root / "language/go/examples/consumer-go/go.mod").write_text(
            "module example.com/starter\n\nrequire github.com/axisvela/praxo-core/v2 v2.7.0\n",
            encoding="utf-8",
        )
        (root / "language/python/examples/consumer/requirements.txt").write_text(
            "praxo-core==0.3.2\n", encoding="utf-8"
        )
        (root / "language/typescript/examples/consumer/package.json").write_text(
            json.dumps({"dependencies": {"@axisvela/praxo-core": "0.2.2"}}),
            encoding="utf-8",
        )
        (root / "language/java/examples/consumer/pom.xml").write_text(
            """<project xmlns="http://maven.apache.org/POM/4.0.0">
  <dependencies>
    <dependency>
      <groupId>com.axisvela</groupId>
      <artifactId>praxo-core</artifactId>
      <version>0.4.1</version>
    </dependency>
  </dependencies>
 </project>""",
            encoding="utf-8",
        )
        (root / "language/ruby/examples/consumer/Gemfile").write_text(
            "source 'https://rubygems.org'\n\ngem 'praxo-core', '0.4.1'\n",
            encoding="utf-8",
        )
        (root / "language/php/examples/consumer/composer.json").write_text(
            json.dumps({"require": {"axisvela/praxo-core": "0.4.0"}}),
            encoding="utf-8",
        )
        (root / "language/elixir/examples/consumer/mix.exs").write_text(
            "defp deps do\n  [{:praxo_core, \"~> 0.4.0\"}]\nend\n",
            encoding="utf-8",
        )
        (root / "language/lua/examples/consumer/README.md").write_text(
            "Uses the published LuaRocks `praxo-core` `0.4.0-1` package.\n",
            encoding="utf-8",
        )
        (root / "language/python/examples/README.md").write_text(
            "- consumer: published PyPI `praxo-core==0.3.2`\n", encoding="utf-8"
        )
        (root / "language/python/examples/consumer/README.md").write_text(
            "This starter installs `praxo-core==0.3.2` from PyPI.\n", encoding="utf-8"
        )
        (root / "language/python/examples/consumer/test_starter.py").write_text(
            'self.assertEqual(distribution.version, "0.3.2")\n', encoding="utf-8"
        )
        (root / "language/typescript/examples/README.md").write_text(
            "- consumer: published npm `@axisvela/praxo-core@0.2.2`\n", encoding="utf-8"
        )
        (root / "language/typescript/examples/consumer/README.md").write_text(
            "This starter installs `@axisvela/praxo-core@0.2.2` from npm.\n",
            encoding="utf-8",
        )
        (root / "language/typescript/examples/consumer/test_starter.test.js").write_text(
            'const expectedVersion = process.env.PRAXO_EXPECTED_VERSION || "0.2.2";\n',
            encoding="utf-8",
        )
        (root / "language/java/examples/README.md").write_text(
            "- consumer: published `com.axisvela:praxo-core:0.4.1`\n", encoding="utf-8"
        )
        (root / "language/java/examples/consumer/README.md").write_text(
            "This starter installs `com.axisvela:praxo-core:0.4.1` and `praxo-core-0.4.1.jar`.\n",
            encoding="utf-8",
        )
        (root / "language/java/examples/consumer/src/test/java/starter/AppTest.java").write_text(
            'assertEquals("0.4.1", Version.SDK_VERSION);\n'
            'assertEquals("praxo-core-0.4.1.jar", filename);\n',
            encoding="utf-8",
        )
        (root / "language/csharp/examples/foo/Foo.csproj").write_text(
            '<PackageReference Include="Praxo.Core" Version="0.8.0" />\n',
            encoding="utf-8",
        )
        (root / "language/csharp/examples/foo/README.md").write_text(
            "Uses published NuGet `Praxo.Core==0.8.0`.\n", encoding="utf-8"
        )
        (root / "language/rust/examples/foo/Cargo.toml").write_text(
            'praxo-core = "0.8.0"\n', encoding="utf-8"
        )
        (root / "language/rust/examples/foo/README.md").write_text(
            "Uses published crates.io `praxo-core@0.8.0`.\n", encoding="utf-8"
        )
        (root / "language/registry-metadata.json").write_text(
            json.dumps(
                {
                    "C#": {"published_version": csharp},
                    "Rust": {"published_version": rust},
                }
            ),
            encoding="utf-8",
        )
        self.root = root

    def tearDown(self):
        self.directory.cleanup()

    def errors(self):
        return check.validate(self.root)

    def test_valid_pins_pass(self):
        self.build()
        self.assertEqual(self.errors(), [])

    def test_python_mismatch_is_rejected(self):
        self.build()
        path = self.root / "language/python/examples/consumer/requirements.txt"
        path.write_text("praxo-core==0.3.1\n", encoding="utf-8")
        self.assertTrue(any("consumer-python" in error for error in self.errors()))

    def test_go_mismatch_is_rejected(self):
        self.build()
        path = self.root / "language/go/examples/consumer-go/go.mod"
        path.write_text(
            "module example.com/starter\n\nrequire github.com/axisvela/praxo-core/v2 v2.6.0\n",
            encoding="utf-8",
        )
        self.assertTrue(any("consumer-go" in error for error in self.errors()))

    def test_ruby_mismatch_is_rejected(self):
        self.build()
        path = self.root / "language/ruby/examples/consumer/Gemfile"
        path.write_text("gem 'praxo-core', '0.4.0'\n", encoding="utf-8")
        self.assertTrue(any("consumer-ruby" in error for error in self.errors()))

    def test_lua_mismatch_is_rejected(self):
        self.build()
        path = self.root / "language/lua/examples/consumer/README.md"
        path.write_text("Uses `praxo-core` `0.3.0-1`.\n", encoding="utf-8")
        self.assertTrue(any("consumer-lua" in error for error in self.errors()))

    def test_python_readme_mismatch_is_rejected(self):
        self.build()
        path = self.root / "language/python/examples/consumer/README.md"
        path.write_text("This starter installs `praxo-core==0.3.1`.\n", encoding="utf-8")
        self.assertTrue(
            any("consumer-python/README.md" in error for error in self.errors())
        )

    def test_typescript_test_mismatch_is_rejected(self):
        self.build()
        path = self.root / "language/typescript/examples/consumer/test_starter.test.js"
        path.write_text(
            'const expectedVersion = process.env.PRAXO_EXPECTED_VERSION || "0.2.1";\n',
            encoding="utf-8",
        )
        self.assertTrue(
            any(
                "consumer-typescript/test_starter.test.js" in error
                for error in self.errors()
            )
        )

    def test_java_test_mismatch_is_rejected(self):
        self.build()
        path = self.root / "language/java/examples/consumer/src/test/java/starter/AppTest.java"
        path.write_text('assertEquals("0.4.0", Version.SDK_VERSION);\n', encoding="utf-8")
        self.assertTrue(
            any("consumer-java/AppTest.java SDK version" in error for error in self.errors())
        )

    def test_csharp_example_mismatch_is_rejected(self):
        self.build()
        path = self.root / "language/csharp/examples/foo/Foo.csproj"
        path.write_text(
            '<PackageReference Include="Praxo.Core" Version="0.7.0" />\n',
            encoding="utf-8",
        )
        self.assertTrue(
            any("language/csharp/examples" in error for error in self.errors())
        )

    def test_rust_example_mismatch_is_rejected(self):
        self.build()
        path = self.root / "language/rust/examples/foo/Cargo.toml"
        path.write_text('praxo-core = "0.7.0"\n', encoding="utf-8")
        self.assertTrue(
            any("language/rust/examples" in error for error in self.errors())
        )


if __name__ == "__main__":
    unittest.main()
