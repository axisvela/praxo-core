from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.agent import Agent, AgentOptions, Session
from praxo.errors import (
    ApprovalDeniedError,
    InterruptDecisionInvalidError,
    InterruptUnhandledError,
)
from praxo.event import Event
from praxo.hitl import (
    INTERRUPT_APPROVE,
    INTERRUPT_EDIT,
    INTERRUPT_REJECT,
    INTERRUPT_RESPOND,
    InterruptDecision,
)
from praxo.model import Message, Response, ToolCall
from praxo.policy import Action, Decision
from praxo.tool import Registry


class ScriptModel:
    def __init__(self, responses):
        self.responses = list(responses)
        self.requests = []

    async def generate(self, request):
        self.requests.append(request)
        return self.responses.pop(0)


class EchoModel:
    def __init__(self):
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
                            name="echo",
                            arguments={"value": "original"},
                        )
                    ],
                )
            )
        for message in reversed(request.messages):
            if message.role == "tool":
                return Response(
                    message=Message(role="assistant", content=message.content)
                )
        return Response(message=Message(role="assistant", content="final"))


class RecordingTool:
    def __init__(self, name: str = "echo"):
        self.name = name
        self.description = name
        self.calls: list[dict] = []

    async def invoke(self, args):
        self.calls.append(args)
        return args


class RecordingSink:
    def __init__(self):
        self.events: list[Event] = []

    async def emit(self, event: Event) -> None:
        self.events.append(event)


class RecordingHook:
    def __init__(self):
        self.actions: list[Action] = []

    async def authorize(self, action: Action) -> Decision:
        self.actions.append(action)
        return Decision(True)


def response(content: str = "", calls: list[ToolCall] | None = None) -> Response:
    return Response(
        message=Message(role="assistant", content=content, tool_calls=calls or [])
    )


def call(arguments: dict | None = None) -> ToolCall:
    return ToolCall(id="call-1", name="echo", arguments=arguments or {"value": "original"})


def build_agent(decision=None, *, events=None, policy=None, approval=None):
    tool = RecordingTool()
    registry = Registry()
    registry.register(tool)
    options = AgentOptions(
        model=ScriptModel([response(calls=[call()]), response("final")]),
        tools=registry,
        events=events,
        policy=policy,
        interrupt_on={"echo"},
        on_interrupt_decision=decision,
        on_interrupt=approval,
    )
    return Agent(options), tool


class HitlTest(unittest.IsolatedAsyncioTestCase):
    async def test_approve_runs_tool_with_original_arguments(self) -> None:
        agent, tool = build_agent(
            lambda interrupt: InterruptDecision(action=INTERRUPT_APPROVE)
        )
        result = await agent.run(Session(id="s1"), "go")
        self.assertEqual(result.output, "final")
        self.assertEqual(tool.calls, [{"value": "original"}])

    async def test_edit_replaces_arguments_and_reauthorizes(self) -> None:
        hook = RecordingHook()
        agent, tool = build_agent(
            lambda interrupt: InterruptDecision(
                action=INTERRUPT_EDIT, arguments={"value": "edited"}
            ),
            policy=hook,
        )
        result = await agent.run(Session(id="s1"), "go")
        self.assertEqual(result.output, "final")
        self.assertEqual(tool.calls, [{"value": "edited"}])
        tool_actions = [
            item for item in hook.actions if item.kind == "tool.invoke"
        ]
        self.assertEqual(
            [(item.tool_name, item.arguments["value"]) for item in tool_actions],
            [("echo", "original"), ("echo", "edited")],
        )

    async def test_reject_fails_without_effects(self) -> None:
        agent, tool = build_agent(
            lambda interrupt: InterruptDecision(
                action=INTERRUPT_REJECT, reason="not allowed"
            )
        )
        with self.assertRaises(ApprovalDeniedError):
            await agent.run(Session(id="s1"), "go")
        self.assertEqual(tool.calls, [])

    async def test_respond_skips_tool_and_feeds_response(self) -> None:
        tool = RecordingTool()
        registry = Registry()
        registry.register(tool)
        agent = Agent(
            AgentOptions(
                model=EchoModel(),
                tools=registry,
                interrupt_on={"echo"},
                on_interrupt_decision=lambda interrupt: InterruptDecision(
                    action=INTERRUPT_RESPOND, response="human answer"
                ),
            )
        )
        result = await agent.run(Session(id="s1"), "go")
        self.assertEqual(result.output, '"human answer"')
        self.assertEqual(tool.calls, [])

    async def test_invalid_decision_fails(self) -> None:
        agent, tool = build_agent(
            lambda interrupt: InterruptDecision(action="invalid")
        )
        with self.assertRaises(InterruptDecisionInvalidError):
            await agent.run(Session(id="s1"), "go")
        self.assertEqual(tool.calls, [])

    async def test_edit_without_arguments_fails(self) -> None:
        agent, tool = build_agent(
            lambda interrupt: InterruptDecision(action=INTERRUPT_EDIT)
        )
        with self.assertRaises(InterruptDecisionInvalidError):
            await agent.run(Session(id="s1"), "go")
        self.assertEqual(tool.calls, [])

    async def test_unhandled_interrupt_fails(self) -> None:
        agent, tool = build_agent(None)
        with self.assertRaises(InterruptUnhandledError):
            await agent.run(Session(id="s1"), "go")
        self.assertEqual(tool.calls, [])

    async def test_boolean_approval_can_deny(self) -> None:
        agent, tool = build_agent(None, approval=lambda interrupt: False)
        with self.assertRaises(ApprovalDeniedError):
            await agent.run(Session(id="s1"), "go")
        self.assertEqual(tool.calls, [])

    async def test_emits_interrupt_event(self) -> None:
        sink = RecordingSink()
        agent, tool = build_agent(
            lambda interrupt: InterruptDecision(action=INTERRUPT_APPROVE),
            events=sink,
        )
        await agent.run(Session(id="s1"), "go")
        events = [event for event in sink.events if event.type == "tool.interrupt"]
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].data["name"], "echo")
        self.assertEqual(events[0].data["arguments"], {"value": "original"})


if __name__ == "__main__":
    unittest.main()
