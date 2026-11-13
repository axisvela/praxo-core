import asyncio
import unittest

from client import demo


class MCPExampleTests(unittest.TestCase):
    def test_lists_and_calls_tool(self):
        output = asyncio.run(demo())
        self.assertEqual(output, "tools=add,echo; sum=5")


if __name__ == "__main__":
    unittest.main()
