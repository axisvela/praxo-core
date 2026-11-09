import json
from pathlib import Path
import tempfile
import unittest

import check_consumer_pins as check


class ConsumerPinTests(unittest.TestCase):
    def build(self, go="2.7.0", python="0.3.2", typescript="0.2.2", java="0.4.1"):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        for path in (
            root / "docs/getting-started",
            root / "examples/consumer-go",
            root / "examples/consumer-python",
            root / "examples/consumer-typescript",
            root / "examples/consumer-java",
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
                    ]
                }
            ),
            encoding="utf-8",
        )
        (root / "examples/consumer-go/go.mod").write_text(
            "module example.com/starter\n\nrequire github.com/axisvela/praxo-core/v2 v2.7.0\n",
            encoding="utf-8",
        )
        (root / "examples/consumer-python/requirements.txt").write_text(
            "praxo-core==0.3.2\n", encoding="utf-8"
        )
        (root / "examples/consumer-typescript/package.json").write_text(
            json.dumps({"dependencies": {"@axisvela/praxo-core": "0.2.2"}}),
            encoding="utf-8",
        )
        (root / "examples/consumer-java/pom.xml").write_text(
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
        path = self.root / "examples/consumer-python/requirements.txt"
        path.write_text("praxo-core==0.3.1\n", encoding="utf-8")
        self.assertTrue(any("consumer-python" in error for error in self.errors()))

    def test_go_mismatch_is_rejected(self):
        self.build()
        path = self.root / "examples/consumer-go/go.mod"
        path.write_text(
            "module example.com/starter\n\nrequire github.com/axisvela/praxo-core/v2 v2.6.0\n",
            encoding="utf-8",
        )
        self.assertTrue(any("consumer-go" in error for error in self.errors()))


if __name__ == "__main__":
    unittest.main()
