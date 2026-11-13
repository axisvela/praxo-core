import asyncio
import unittest

from praxo.model import Message, Response, ToolCall

from event_sink import RecordingSink, run


class ToolThenAnswerModel:
    def __init__(self) -> None:
        self.calls = 0

    async def generate(self, request):
        self.calls += 1
        if self.calls == 1:
            return Response(
                message=Message(
                    role="assistant",
                    tool_calls=[
                        ToolCall(
                            id="call-1",
                            name="lookup",
                            arguments={"key": "status"},
                        )
                    ],
                )
            )
        return Response(message=Message(role="assistant", content="status: green"))


class EventSinkTests(unittest.TestCase):
    def test_records_run_and_tool_events(self):
        model = ToolThenAnswerModel()
        all_sink = RecordingSink()
        tool_sink = RecordingSink()

        output = asyncio.run(run(model, all_sink, tool_sink))

        self.assertEqual(output, "status: green")
        self.assertEqual(
            all_sink.types(),
            ["run.started", "tool.call", "run.completed"],
        )
        self.assertEqual(tool_sink.types(), ["tool.call"])
        self.assertEqual(tool_sink.events[0].data["name"], "lookup")


if __name__ == "__main__":
    unittest.main()
