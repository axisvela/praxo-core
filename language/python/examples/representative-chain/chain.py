from __future__ import annotations

import asyncio
import json
import sys
from typing import Any

from praxo import (
    Agent,
    AgentOptions,
    Decision,
    FuncHook,
    Message,
    Middleware,
    Registry,
    Response,
    Session,
    ToolCall,
)
from praxo.adapters.harmovela import HarmovelaSink
from praxo.adapters.mcp import MCPClient, MCPToolAdapter
from praxo.adapters.otel import OtelSink
from praxo.errors import PolicyDeniedError
from praxo.event import MultiSink


class FakeMCPTransport:
    def __init__(self, effects: dict[str, int]) -> None:
        self.effects = effects
        self.queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue()
        self.closed = False

    async def start(self) -> None:
        return None

    async def send(self, message: dict[str, Any]) -> None:
        method = message.get("method")
        request_id = message.get("id")
        params = message.get("params") or {}
        if method == "initialize":
            result = {
                "protocolVersion": params.get("protocolVersion", "2024-11-05"),
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "fake-mcp", "version": "0.0.1"},
            }
        elif method == "tools/list":
            result = {
                "tools": [
                    {
                        "name": "record",
                        "description": "Record a target",
                        "inputSchema": {
                            "type": "object",
                            "properties": {"target": {"type": "string"}},
                            "required": ["target"],
                        },
                    }
                ]
            }
        elif method == "tools/call":
            name = params.get("name")
            arguments = params.get("arguments") or {}
            if name != "record":
                result = {
                    "isError": True,
                    "content": [{"type": "text", "text": "unknown tool"}],
                }
            else:
                target = str(arguments.get("target", ""))
                self.effects[target] = self.effects.get(target, 0) + 1
                result = {
                    "content": [{"type": "text", "text": f"recorded:{target}"}]
                }
        else:
            result = {}
        if request_id is not None:
            await self.queue.put(
                {"jsonrpc": "2.0", "id": request_id, "result": result}
            )

    async def receive(self) -> dict[str, Any] | None:
        return await self.queue.get()

    async def close(self) -> None:
        self.closed = True


class ScriptedModel:
    def __init__(self, steps: list[dict[str, Any]], final: str) -> None:
        self.steps = list(steps)
        self.final = final
        self.calls = 0

    async def generate(self, request: Any) -> Response:
        self.calls += 1
        if self.steps:
            step = self.steps.pop(0)
            return Response(
                message=Message(
                    role="assistant",
                    content=step.get("content", ""),
                    tool_calls=step.get("tool_calls", []),
                )
            )
        return Response(message=Message(role="assistant", content=self.final))


class ComposedPolicy:
    def __init__(self, hooks: list[Any]) -> None:
        self.hooks = [hook for hook in hooks if hook is not None]

    async def authorize(self, action: Any) -> Decision:
        for hook in self.hooks:
            decision = await hook.authorize(action)
            if not decision.allowed:
                return decision
        return Decision(True, "delegation policy chain allowed")


def parent_policy(action: Any) -> Decision:
    if action.kind == "model.generate":
        return Decision(True)
    if action.kind != "tool.invoke":
        return Decision(False, "unsupported action")
    if action.tool_name == "record":
        if action.arguments.get("target") == "blocked":
            return Decision(False, "blocked target")
        return Decision(True)
    if action.tool_name == "delegate":
        return Decision(True)
    return Decision(False, "parent tool is not allowed")


def child_only_policy(action: Any) -> Decision:
    if action.kind == "model.generate":
        return Decision(True)
    if action.kind == "tool.invoke" and action.tool_name == "record":
        return Decision(True)
    return Decision(False, "child may only record")


class DelegateTool:
    name = "delegate"
    description = "Run a governed child agent with the narrowed record scope"
    parameters = {
        "type": "object",
        "properties": {"task": {"type": "string"}},
        "required": ["task"],
    }

    def __init__(
        self,
        record: Any,
        child_model: ScriptedModel,
        effects: dict[str, int],
        events: Any,
    ) -> None:
        self.record = record
        self.child_model = child_model
        self.effects = effects
        self.events = events

    async def invoke(self, arguments: dict[str, Any]) -> dict[str, Any]:
        registry = Registry()
        registry.register(self.record)
        child = Agent(
            AgentOptions(
                model=self.child_model,
                tools=registry,
                max_steps=3,
                allowed_tools=["record"],
                policy=ComposedPolicy(
                    [FuncHook(parent_policy), FuncHook(child_only_policy)]
                ),
                require_policy=True,
                require_tool_scope=True,
                events=self.events,
            )
        )
        result = await child.run(Session(id="chain-child"), "record child")
        return {
            "output": result.output,
            "effects": self.effects.get("child", 0),
        }


def otel_transport(log: list[str]) -> Any:
    def send(_endpoint: str, _headers: dict[str, str], body: bytes) -> tuple[int, bytes]:
        payload = json.loads(body.decode("utf-8"))
        for resource in payload.get("resourceSpans", []):
            for scope in resource.get("scopeSpans", []):
                for span in scope.get("spans", []):
                    log.append(span.get("name", ""))
        return 200, b""

    return send


def harmovela_transport(log: list[str]) -> Any:
    def send(
        _method: str,
        _url: str,
        _headers: dict[str, str],
        body: bytes,
    ) -> tuple[int, bytes]:
        payload = json.loads(body.decode("utf-8"))
        log.append(payload.get("type", ""))
        return 202, b""

    return send


async def run_chain() -> dict[str, Any]:
    effects: dict[str, int] = {}
    transport = FakeMCPTransport(effects)
    client = MCPClient(transport=transport)
    await client.connect()
    try:
        tools = await client.list_tools()
        record = MCPToolAdapter(client, tools[0])
        otel_log: list[str] = []
        harmovela_log: list[str] = []
        events = MultiSink(
            [
                OtelSink(transport=otel_transport(otel_log)),
                HarmovelaSink(
                    base_url="http://harmovela.local",
                    transport=harmovela_transport(harmovela_log),
                ),
            ]
        )
        child_model = ScriptedModel(
            [
                {
                    "tool_calls": [
                        ToolCall(
                            id="child-record",
                            name="record",
                            arguments={"target": "child"},
                        )
                    ]
                }
            ],
            "CHILD-DONE",
        )
        parent_model = ScriptedModel(
            [
                {
                    "tool_calls": [
                        ToolCall(
                            id="parent-record",
                            name="record",
                            arguments={"target": "parent"},
                        )
                    ]
                },
                {
                    "tool_calls": [
                        ToolCall(
                            id="parent-delegate",
                            name="delegate",
                            arguments={"task": "child"},
                        )
                    ]
                },
            ],
            "DONE",
        )
        registry = Registry()
        registry.register(record)
        registry.register(
            DelegateTool(record, child_model, effects, events)
        )
        parent = Agent(
            AgentOptions(
                model=parent_model,
                tools=registry,
                max_steps=6,
                allowed_tools=["record", "delegate"],
                policy=FuncHook(parent_policy),
                require_policy=True,
                require_tool_scope=True,
                events=events,
            )
        )
        result = await parent.run(
            Session(id="chain-parent"), "run the representative chain"
        )
        return {
            "output": result.output,
            "effects": dict(effects),
            "child_calls": child_model.calls,
            "otel": otel_log,
            "harmovela": harmovela_log,
        }
    finally:
        await client.close()


async def run_denial() -> tuple[int, str]:
    effects: dict[str, int] = {}
    transport = FakeMCPTransport(effects)
    client = MCPClient(transport=transport)
    await client.connect()
    try:
        tools = await client.list_tools()
        record = MCPToolAdapter(client, tools[0])
        registry = Registry()
        registry.register(record)

        async def edit(call: Any) -> None:
            call.call.arguments["target"] = "blocked"

        model = ScriptedModel(
            [
                {
                    "tool_calls": [
                        ToolCall(
                            id="denied-record",
                            name="record",
                            arguments={"target": "safe"},
                        )
                    ]
                }
            ],
            "UNEXPECTED",
        )
        agent = Agent(
            AgentOptions(
                model=model,
                tools=registry,
                max_steps=2,
                allowed_tools=["record"],
                policy=FuncHook(parent_policy),
                middleware=[Middleware(before_tool=edit)],
                require_policy=True,
                require_tool_scope=True,
            )
        )
        try:
            await agent.run(Session(id="chain-denial"), "call record")
        except PolicyDeniedError as error:
            return effects.get("blocked", 0), error.code
        raise RuntimeError("denial path unexpectedly succeeded")
    finally:
        await client.close()


async def main() -> None:
    result = await run_chain()
    assert result["output"] == "DONE", result
    assert result["effects"].get("parent") == 1, result
    assert result["effects"].get("child") == 1, result
    assert result["child_calls"] >= 2, result
    for span in ("praxo.run.started", "praxo.tool.call", "praxo.run.completed"):
        assert span in result["otel"], result
    for kind in ("run.started", "tool.call", "run.completed"):
        assert kind in result["harmovela"], result
    blocked, code = await run_denial()
    assert blocked == 0, blocked
    assert code == "AGENT_POLICY_DENIED", code
    print("output:", result["output"])
    print("effects:", result["effects"])
    print("child calls:", result["child_calls"])
    print("otel spans:", len(result["otel"]))
    print("harmovela events:", len(result["harmovela"]))
    print("denied effects:", blocked)


if __name__ == "__main__":
    asyncio.run(main())
