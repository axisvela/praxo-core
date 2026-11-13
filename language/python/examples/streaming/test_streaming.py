import asyncio
import unittest

from streaming import StreamingModel, run


class StreamingTests(unittest.TestCase):
    def test_deltas_reconstruct_the_final_output(self):
        chunks = ["status: ", "green"]
        received = []

        output = asyncio.run(run(StreamingModel(chunks), received.append))

        self.assertEqual(output, "status: green")
        self.assertEqual(received, chunks)
        self.assertEqual("".join(received), output)


if __name__ == "__main__":
    unittest.main()
