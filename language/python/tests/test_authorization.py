from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import PolicyDeniedError
from praxo.middleware import Middleware
from praxo.model import Message, Response, ToolCall
from praxo.policy import Action, Decision
from praxo.tool import Registry


def response(content: str = "", calls: list[ToolCall] | None = None) -> Response:
    return Response(
        message=Message(role="assistant", content=content, tool_calls=calls or [])
    )


def call(name: str, arguments: dict | None = None) -> ToolCall:
    return ToolCall(id=f"c-{name}", name=name, arguments=arguments or {})


class ScriptModel:
    def __init__(self, responses):
        self.responses = list(responses)

    async def generate(self, request):
        return self.responses.pop(0)


class RecordingHook:
    def __init__(self, deny=None):
        self.actions: list[Action] = []
        self.deny = deny

    async def authorize(self, action: Action) -> Decision:
        self.actions.append(action)
        if self.deny is not None and self.deny(action):
            return Decision(False, "denied by fixture")
        return Decision(True)


class RecordingTool:
    def __init__(self, name: str):
        self.name = name
        self.description = name
        self.calls: list[dict] = []

    async def invoke(self, args):
        self.calls.append(args)
        return args


class AuthorizationTest(unittest.IsolatedAsyncioTestCase):
    async def test_middleware_argument_change_is_reauthorized(self) -> None:
        tool = RecordingTool("echo")
        registry = Registry()
        registry.register(tool)
        hook = RecordingHook(
            deny=lambda action: action.arguments.get("text") == "denied"
        )
        middleware = Middleware(
            before_tool=lambda item: setattr(
                item.call, "arguments", {"text": "denied"}
            )
        )
        agent = Agent(
            AgentOptions(
                model=ScriptModel([response(calls=[call("echo", {"text": "ok"})])]),
                tools=registry,
                policy=hook,
                middleware=[middleware],
            )
        )
        with self.assertRaises(PolicyDeniedError):
            await agent.run(Session(id="s1"), "go")
        self.assertEqual(tool.calls, [])
        tool_actions = [item for item in hook.actions if item.kind == "tool.invoke"]
        self.assertEqual(
            [(item.tool_name, item.arguments) for item in tool_actions],
            [("echo", {"text": "ok"}), ("echo", {"text": "denied"})],
        )

    async def test_middleware_name_change_uses_final_tool_and_authorization(self) -> None:
        original = RecordingTool("echo")
        replacement = RecordingTool("admin")
        registry = Registry()
        registry.register(original)
        registry.register(replacement)
        hook = RecordingHook()
        middleware = Middleware(
            before_tool=lambda item: setattr(item.call, "name", "admin")
        )
        agent = Agent(
            AgentOptions(
                model=ScriptModel(
                    [
                        response(calls=[call("echo")]),
                        response("done"),
                    ]
                ),
                tools=registry,
                policy=hook,
                middleware=[middleware],
            )
        )
        result = await agent.run(Session(id="s1"), "go")
        self.assertEqual(result.output, "done")
        self.assertEqual(original.calls, [])
        self.assertEqual(replacement.calls, [{}])
        tool_actions = [item for item in hook.actions if item.kind == "tool.invoke"]
        self.assertEqual([item.tool_name for item in tool_actions], ["echo", "admin"])

    async def test_unchanged_tool_is_authorized_once(self) -> None:
        tool = RecordingTool("echo")
        registry = Registry()
        registry.register(tool)
        hook = RecordingHook()
        agent = Agent(
            AgentOptions(
                model=ScriptModel(
                    [
                        response(calls=[call("echo", {"text": "ok"})]),
                        response("done"),
                    ]
                ),
                tools=registry,
                policy=hook,
            )
        )
        await agent.run(Session(id="s1"), "go")
        tool_actions = [item for item in hook.actions if item.kind == "tool.invoke"]
        self.assertEqual(len(tool_actions), 1)
        self.assertEqual(tool.calls, [{"text": "ok"}])

    async def test_initial_denial_prevents_middleware_and_effect(self) -> None:
        tool = RecordingTool("echo")
        registry = Registry()
        registry.register(tool)
        hook = RecordingHook(deny=lambda action: True)
        middleware = Middleware(
            before_tool=lambda item: self.fail("middleware should not run")
        )
        agent = Agent(
            AgentOptions(
                model=ScriptModel([response(calls=[call("echo")])]),
                tools=registry,
                policy=hook,
                middleware=[middleware],
            )
        )
        with self.assertRaises(PolicyDeniedError):
            await agent.run(Session(id="s1"), "go")
        self.assertEqual(tool.calls, [])

    async def test_final_name_must_remain_allowed(self) -> None:
        replacement = RecordingTool("admin")
        registry = Registry()
        registry.register(RecordingTool("echo"))
        registry.register(replacement)
        middleware = Middleware(
            before_tool=lambda item: setattr(item.call, "name", "admin")
        )
        agent = Agent(
            AgentOptions(
                model=ScriptModel([response(calls=[call("echo")])]),
                tools=registry,
                allowed_tools=["echo"],
                middleware=[middleware],
            )
        )
        with self.assertRaises(ValueError):
            await agent.run(Session(id="s1"), "go")
        self.assertEqual(replacement.calls, [])


if __name__ == "__main__":
    unittest.main()
