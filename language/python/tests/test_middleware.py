from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from praxo.agent import Agent, AgentOptions, Session
from praxo.context import ContextBudget, OffloadFunc
from praxo.errors import (
    ContextBudgetError,
    ModelCallLimitError,
    StructuredOutputError,
    ToolCallLimitError,
    ToolNotSelectedError,
)
from praxo.middleware import (
    ModelCall,
    PIIRedactor,
    RunState,
    StructuredOutput,
    call_limit_middleware,
    default_pii_rules,
    pii_middleware,
)
from praxo.model import Message, Request, Response, ToolCall, Usage
from praxo.tool import Registry


def response(content: str = "", calls: list[ToolCall] | None = None) -> Response:
    return Response(
        message=Message(
            role="assistant",
            content=content,
            tool_calls=calls or [],
        )
    )


def call(name: str, arguments: dict | None = None) -> ToolCall:
    return ToolCall(id=f"c-{name}", name=name, arguments=arguments or {})


class ScriptModel:
    def __init__(self, responses):
        self.responses = list(responses)
        self.requests = []

    async def generate(self, request):
        self.requests.append(request)
        item = self.responses.pop(0)
        if isinstance(item, Exception):
            raise item
        return item


class EchoTool:
    def __init__(self, name="echo", result=None, error=None):
        self.name = name
        self.description = name
        self.result = result
        self.error = error

    async def invoke(self, args):
        if self.error is not None:
            raise self.error
        return self.result if self.result is not None else args


class FixedSelector:
    def __init__(self, names):
        self.names = names

    async def select(self, query, tools):
        return self.names


class MiddlewareTest(unittest.IsolatedAsyncioTestCase):
    async def test_pii_redacts_model_messages(self) -> None:
        model = ScriptModel([response("done")])
        agent = Agent(
            AgentOptions(
                model=model,
                pii_redactor=PIIRedactor(default_pii_rules()),
            )
        )
        await agent.run(Session(id="s1"), "email a@b.com")
        content = model.requests[0].messages[-1].content
        self.assertNotIn("a@b.com", content)
        self.assertIn("[REDACTED:email]", content)

    async def test_pii_redacts_tool_call_history(self) -> None:
        middleware = pii_middleware(
            PIIRedactor(default_pii_rules())
        )
        call = ModelCall(
            run_id="r1",
            session_id="s1",
            request=Request(
                messages=[
                    Message(
                        role="assistant",
                        tool_calls=[
                            ToolCall(
                                id="call-1",
                                name="lookup",
                                arguments={
                                    "email": "a@b.com",
                                    "nested": {"ssn": "123-45-6789"},
                                },
                            )
                        ],
                    )
                ]
            ),
        )
        await middleware.before_model(call)
        arguments = call.request.messages[0].tool_calls[0].arguments
        self.assertEqual(arguments["email"], "[REDACTED:email]")
        self.assertEqual(
            arguments["nested"]["ssn"], "[REDACTED:ssn]"
        )

    async def test_model_call_limit(self) -> None:
        registry = Registry()
        registry.register(EchoTool())
        model = ScriptModel(
            [response(calls=[call("echo")]), response("done")]
        )
        agent = Agent(
            AgentOptions(model=model, tools=registry, model_call_limit=1)
        )
        with self.assertRaises(ModelCallLimitError):
            await agent.run(Session(id="s1"), "go")

    async def test_tool_call_limit(self) -> None:
        registry = Registry()
        registry.register(EchoTool())
        model = ScriptModel([response(calls=[call("echo"), call("echo")])])
        agent = Agent(
            AgentOptions(model=model, tools=registry, tool_call_limit=1)
        )
        with self.assertRaises(ToolCallLimitError):
            await agent.run(Session(id="s1"), "go")

    async def test_call_limit_state_is_isolated_by_run(self) -> None:
        middleware = call_limit_middleware(1, 0)
        await middleware.before_run(RunState("a", None, ""))
        await middleware.before_run(RunState("b", None, ""))
        await middleware.before_model(
            ModelCall("a", "s1", Request(messages=[]))
        )
        await middleware.before_model(
            ModelCall("b", "s1", Request(messages=[]))
        )

    async def test_fallback_model(self) -> None:
        primary = ScriptModel([RuntimeError("primary")])
        fallback = ScriptModel([response("fallback")])
        agent = Agent(
            AgentOptions(model=primary, fallback_model=fallback)
        )
        result = await agent.run(Session(id="s1"), "go")
        self.assertEqual(result.output, "fallback")

    async def test_tool_selection_filters_specs(self) -> None:
        registry = Registry()
        registry.register(EchoTool("echo"))
        registry.register(EchoTool("other"))
        model = ScriptModel([response("done")])
        agent = Agent(
            AgentOptions(
                model=model,
                tools=registry,
                tool_selector=FixedSelector(["echo"]),
            )
        )
        await agent.run(Session(id="s1"), "go")
        names = [spec.name for spec in model.requests[0].tools]
        self.assertEqual(names, ["echo"])

    async def test_tool_selection_rejects_unselected(self) -> None:
        registry = Registry()
        registry.register(EchoTool("echo"))
        registry.register(EchoTool("other"))
        model = ScriptModel([response(calls=[call("echo")])])
        agent = Agent(
            AgentOptions(
                model=model,
                tools=registry,
                tool_selector=FixedSelector(["other"]),
            )
        )
        with self.assertRaises(ToolNotSelectedError):
            await agent.run(Session(id="s1"), "go")

    async def test_structured_output_valid(self) -> None:
        schema = {
            "type": "object",
            "properties": {"value": {"type": "integer"}},
            "required": ["value"],
        }
        model = ScriptModel([response('{"value":1}')])
        agent = Agent(
            AgentOptions(
                model=model,
                structured_output=StructuredOutput(schema=schema),
            )
        )
        result = await agent.run(Session(id="s1"), "go")
        self.assertEqual(result.output, '{"value":1}')

    async def test_structured_output_repair(self) -> None:
        schema = {
            "type": "object",
            "properties": {"value": {"type": "integer"}},
            "required": ["value"],
        }
        model = ScriptModel([response('{"value":"bad"}')])
        agent = Agent(
            AgentOptions(
                model=model,
                structured_output=StructuredOutput(
                    schema=schema,
                    max_repairs=1,
                    repair=lambda output, error: '{"value":2}',
                ),
            )
        )
        result = await agent.run(Session(id="s1"), "go")
        self.assertEqual(result.output, '{"value":2}')

    async def test_structured_output_invalid(self) -> None:
        model = ScriptModel([response("not json")])
        agent = Agent(
            AgentOptions(
                model=model,
                structured_output=StructuredOutput(schema={"type": "object"}),
            )
        )
        with self.assertRaises(StructuredOutputError):
            await agent.run(Session(id="s1"), "go")

    async def test_offload_large_tool_result(self) -> None:
        registry = Registry()
        registry.register(EchoTool(result={"blob": "x" * 200}))
        model = ScriptModel(
            [response(calls=[call("echo")]), response("done")]
        )

        async def offload(tool, call_id, data):
            return "[offloaded]"

        agent = Agent(
            AgentOptions(
                model=model,
                tools=registry,
                offloader=OffloadFunc(offload),
                offload_threshold_bytes=10,
            )
        )
        await agent.run(Session(id="s1"), "go")
        tool_messages = [
            message
            for message in model.requests[1].messages
            if message.role == "tool"
        ]
        self.assertEqual(tool_messages[0].content, "[offloaded]")

    async def test_agents_md_loaded(self) -> None:
        with tempfile.TemporaryDirectory() as base:
            path = Path(base) / "AGENTS.md"
            path.write_text("alpha instructions", encoding="utf-8")
            model = ScriptModel([response("done")])
            agent = Agent(
                AgentOptions(model=model, memory_files=[str(path)])
            )
            await agent.run(Session(id="s1"), "go")
            system = model.requests[0].messages[0]
            self.assertEqual(system.role, "system")
            self.assertIn("alpha instructions", system.content)

    async def test_context_budget_fails_closed(self) -> None:
        model = ScriptModel([response("done")])
        agent = Agent(
            AgentOptions(
                model=model,
                system_prompt="x" * 1000,
                context=ContextBudget(max_tokens=10),
            )
        )
        with self.assertRaises(ContextBudgetError):
            await agent.run(Session(id="s1"), "go")


if __name__ == "__main__":
    unittest.main()
