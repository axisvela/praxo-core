import asyncio
import unittest

from retry import FlakyModel, run


class RetryTests(unittest.TestCase):
    def test_retries_transient_failures(self):
        model = FlakyModel(failures=2)
        output = asyncio.run(run(model, max_attempts=3))
        self.assertEqual(output, "status: green")
        self.assertEqual(model.calls, 3)

    def test_exhausted_attempts_preserve_the_error(self):
        model = FlakyModel(failures=3)
        with self.assertRaises(Exception) as caught:
            asyncio.run(run(model, max_attempts=3))
        self.assertEqual(caught.exception.code, "MODEL_UNAVAILABLE")
        self.assertEqual(model.calls, 3)


if __name__ == "__main__":
    unittest.main()
