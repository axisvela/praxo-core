from __future__ import annotations

import asyncio
from typing import Any

from .agent import Agent, AgentOptions, Session
from .errors import PraxoError
from .event import Event
from .model import ROLE_ASSISTANT, Message, Response, ToolCall, Usage
from .tool import Registry


def run_agent_loop(vector: dict[str, Any]) -> None:
    asyncio.run(_run_agent_loop(vector))


async def _run_agent_loop(vector: dict[str, Any]) -> None:
    inp = vector["input"]
    exp = vector["expect"]
    counter = [0]
    registry = Registry()
    for tool in inp.get("tools", []):
        registry.register(
            _EchoTool(tool.get("name", ""), tool.get("description", ""), counter)
        )
    sink = _RecordingSink()
    agent = Agent(
        AgentOptions(
            model=_ScriptedModel(inp.get("script", [])),
            tools=registry,
            events=sink,
            max_steps=inp.get("maxSteps", 0),
            max_tokens=inp.get("maxTokens", 0),
        )
    )
    error: Exception | None = None
    result = None
    try:
        result = await agent.run(Session(id="s1"), inp.get("prompt", ""))
    except Exception as exc:
        error = exc

    if exp.get("error"):
        _check(error is not None, "expected an error")
        code = exp.get("errorCode")
        if code:
            _check(isinstance(error, PraxoError), f"error: got {error!r}")
            _check(error.code == code, f"errorCode: got {error.code!r}")
    else:
        _check(error is None, f"unexpected error: {error!r}")

    if result is not None:
        _check(result.output == exp.get("output", ""), f"output: got {result.output!r}")
        _check(result.steps == exp.get("steps", 0), f"steps: got {result.steps}")
    _check(
        counter[0] == exp.get("toolInvocations", 0),
        f"tool invocations: got {counter[0]}",
    )
    got_events = sink.types or None
    _check(
        got_events == (exp.get("events") or None),
        f"events: got {got_events!r}",
    )


class _RecordingSink:
    def __init__(self) -> None:
        self.types: list[str] = []

    async def emit(self, event: Event) -> None:
        self.types.append(event.type)


class _EchoTool:
    def __init__(self, name: str, description: str, counter: list[int]) -> None:
        self.name = name
        self.description = description
        self.counter = counter

    async def invoke(self, args: dict[str, Any]) -> Any:
        self.counter[0] += 1
        return args


class _ScriptedModel:
    def __init__(self, steps: list[dict[str, Any]]) -> None:
        self.steps = steps
        self.next = 0

    async def generate(self, request: Any) -> Response:
        if self.next >= len(self.steps):
            raise AssertionError("script exhausted")
        step = self.steps[self.next]
        self.next += 1
        calls = [
            ToolCall(
                id=call.get("id", ""),
                name=call.get("name", ""),
                arguments=call.get("arguments") or {},
            )
            for call in step.get("toolCalls", [])
        ]
        return Response(
            message=Message(
                role=ROLE_ASSISTANT,
                content=step.get("content", ""),
                tool_calls=calls,
            ),
            usage=Usage(
                input_tokens=step.get("inputTokens", 0),
                output_tokens=step.get("outputTokens", 0),
            ),
        )


def _check(condition: bool, detail: str) -> None:
    if not condition:
        raise AssertionError(detail)
