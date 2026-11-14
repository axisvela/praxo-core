import unittest
from contextlib import redirect_stdout
import io

from starter import run


class SessionCheckpointTests(unittest.IsolatedAsyncioTestCase):
    async def test_restores_multi_turn_history(self):
        output = io.StringIO()
        with redirect_stdout(output):
            await run()
        self.assertEqual(
            output.getvalue(),
            "restored messages: 4\noutput: turn 5\n",
        )


if __name__ == "__main__":
    unittest.main()
