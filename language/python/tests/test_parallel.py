from __future__ import annotations

import asyncio
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.agent import Agent, AgentOptions, Session
from praxo.model import Message, Response, ToolCall
from praxo.tool import Registry


class ParallelToolTest(unittest.IsolatedAsyncioTestCase):
    async def test_tools_start_in_parallel_and_keep_call_order(self) -> None:
        class Model:
            def __init__(self) -> None:
                self.requests = []
                self.step = 0

            async def generate(self, request):
                self.requests.append(request)
                self.step += 1
                if self.step == 1:
                    return Response(
                        message=Message(
                            role="assistant",
                            content="",
                            tool_calls=[
                                ToolCall(
                                    id="c1",
                                    name="barrier",
                                    arguments={"value": 1},
                                ),
                                ToolCall(
                                    id="c2",
                                    name="barrier",
                                    arguments={"value": 2},
                                ),
                            ],
                        )
                    )
                return Response(
                    message=Message(role="assistant", content="done")
                )

        class BarrierTool:
            name = "barrier"
            description = "waits for both calls"

            def __init__(self) -> None:
                self.barrier = asyncio.Barrier(2)
                self.calls = []

            async def invoke(self, args):
                self.calls.append(args)
                await self.barrier.wait()
                return args

        tool = BarrierTool()
        registry = Registry()
        registry.register(tool)
        model = Model()
        agent = Agent(
            AgentOptions(
                model=model,
                tools=registry,
                max_parallel_tools=2,
            )
        )
        result = await asyncio.wait_for(
            agent.run(Session(id="s1"), "go"), timeout=5
        )
        self.assertEqual(result.output, "done")
        self.assertEqual(tool.calls, [{"value": 1}, {"value": 2}])
        tool_messages = [
            message
            for message in model.requests[1].messages
            if message.role == "tool"
        ]
        self.assertEqual(
            [message.tool_id for message in tool_messages],
            ["c1", "c2"],
        )


if __name__ == "__main__":
    unittest.main()
