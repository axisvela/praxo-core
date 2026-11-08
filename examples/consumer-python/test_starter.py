import importlib.metadata
import io
from pathlib import Path
import sys
import unittest

import praxo
from praxo.agent import Session
from praxo.errors import PolicyDeniedError

from starter import build_agent, run


class StarterTests(unittest.IsolatedAsyncioTestCase):
    async def test_allowed_tool(self):
        agent, impl = build_agent("public")
        result = await agent.run(Session(id="test-public"), "Record the requested target.")
        self.assertEqual(result.output, "recorded")
        self.assertEqual(impl.calls, 1)

    async def test_denied_tool_has_no_effect(self):
        agent, impl = build_agent("private")
        with self.assertRaises(PolicyDeniedError):
            await agent.run(Session(id="test-private"), "Record the requested target.")
        self.assertEqual(impl.calls, 0)

    async def test_starter_output(self):
        output = io.StringIO()
        await run(output)
        self.assertEqual(output.getvalue(), "allow: recorded; effects=1\ndeny: policy rejected; effects=0\n")

    def test_published_dependency(self):
        self.assertNotEqual(sys.prefix, sys.base_prefix, "use a dedicated virtual environment")
        distribution = importlib.metadata.distribution("praxo-core")
        self.assertEqual(distribution.version, "0.3.2")
        self.assertEqual(praxo.__version__, "0.3.2")
        self.assertTrue(Path(praxo.__file__).resolve().is_relative_to(Path(sys.prefix).resolve()))
        self.assertIsNone(distribution.read_text("direct_url.json"), "install from the registry, not a local path")


if __name__ == "__main__":
    unittest.main()
