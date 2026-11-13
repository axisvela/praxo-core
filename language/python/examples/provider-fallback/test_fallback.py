import asyncio
import unittest

from praxo.model import Message, Response

from fallback import run


class FailingModel:
    def __init__(self):
        self.calls = 0

    async def generate(self, request):
        self.calls += 1
        raise RuntimeError("primary unavailable")


class StaticModel:
    def __init__(self, content):
        self.content = content
        self.calls = 0

    async def generate(self, request):
        self.calls += 1
        return Response(message=Message(role="assistant", content=self.content))


class ProviderFallbackTests(unittest.TestCase):
    def test_uses_fallback_after_primary_failure(self):
        primary = FailingModel()
        fallback = StaticModel("fallback response")
        output = asyncio.run(run(primary, fallback))
        self.assertEqual(output, "fallback response")
        self.assertEqual(primary.calls, 1)
        self.assertEqual(fallback.calls, 1)

    def test_primary_is_used_when_it_succeeds(self):
        primary = StaticModel("primary response")
        fallback = StaticModel("fallback response")
        output = asyncio.run(run(primary, fallback))
        self.assertEqual(output, "primary response")
        self.assertEqual(primary.calls, 1)
        self.assertEqual(fallback.calls, 0)

    def test_both_failures_are_reported(self):
        with self.assertRaises(Exception):
            asyncio.run(run(FailingModel(), FailingModel()))


if __name__ == "__main__":
    unittest.main()
