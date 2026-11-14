import io
import unittest

from starter import run


class HitlStarterTests(unittest.IsolatedAsyncioTestCase):
    async def test_approve_and_edit_scenarios(self):
        output = io.StringIO()
        await run(output)
        self.assertEqual(
            output.getvalue(),
            "approve: written; effects=1\nedit: policy rejected; effects=0\n",
        )


if __name__ == "__main__":
    unittest.main()
