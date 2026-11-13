import asyncio
import json
import unittest

from praxo.model import Message, Response

from summarize import summarize


class FakeModel:
    async def generate(self, request):
        return Response(
            message=Message(
                role="assistant",
                content=json.dumps(
                    {
                        "title": "Release status",
                        "summary": "All checks are green.",
                        "tags": ["release", "status"],
                    }
                ),
            )
        )


class StructuredOutputTests(unittest.TestCase):
    def test_summary_matches_schema(self):
        output = asyncio.run(summarize("Quarterly status: all checks green.", FakeModel()))
        data = json.loads(output)
        self.assertEqual(set(data), {"title", "summary", "tags"})
        self.assertIsInstance(data["tags"], list)


if __name__ == "__main__":
    unittest.main()
