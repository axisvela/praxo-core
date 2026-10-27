import json
import os
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).with_name("praxo_bridge.pl")


class PrologBridgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.swipl = os.environ.get("SWIPL") or shutil.which("swipl")
        if not cls.swipl:
            raise unittest.SkipTest("SWI-Prolog is required")
        cls.binary = ROOT / "build" / ("praxo-bridge.exe" if os.name == "nt" else "praxo-bridge")
        cls.binary.parent.mkdir(exist_ok=True)
        subprocess.run(["go", "build", "-o", str(cls.binary), "./cmd/praxo-bridge"],
                       cwd=ROOT, check=True, timeout=120)

    def invoke(self, arguments, payload):
        env = os.environ.copy()
        env["PRAXO_BRIDGE_BIN"] = str(self.binary)
        return subprocess.run([self.swipl, "-q", "-s", str(SCRIPT), "--", *arguments],
                              input=json.dumps(payload).encode("utf-8"),
                              capture_output=True, env=env, timeout=60)

    def test_version(self):
        result = self.invoke(["version"], {})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["specVersion"], "0.2.0")

    def test_toolcall_unicode(self):
        result = self.invoke(["toolcall", "parse"],
                             {"content": json.dumps({"name": "echo", "input": {"text": "é😀"}})})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["call"]["input"], {"text": "é😀"})

    def test_strip(self):
        result = self.invoke(["toolcall", "strip"],
                             {"content": 'hello<tool_call name="echo">{}</tool_call>world'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["text"], "helloworld")

    def test_schema(self):
        result = self.invoke(["jsonschema", "validate"],
                             {"schema": {"type": "object", "required": ["name"]}, "data": {}})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["errorPaths"], ["$.name"])

    def test_contract_error_exit(self):
        env = os.environ.copy()
        env["PRAXO_BRIDGE_BIN"] = str(self.binary)
        result = subprocess.run([self.swipl, "-q", "-s", str(SCRIPT), "--", "toolcall", "parse"],
                                input=b"{", capture_output=True, env=env, timeout=60)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(json.loads(result.stdout)["error"]["code"], "BRIDGE_JSON")


if __name__ == "__main__":
    unittest.main()
