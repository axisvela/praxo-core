from __future__ import annotations

import asyncio
import json
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .agent import Agent, AgentOptions, Session
from .checkpoint import Allowlist
from .context import ContextBudget, estimate_tokens
from .errors import PluginError, PolicyError, PraxoError, TypeNotAllowedError
from .event import Event, FilterSink, MultiSink
from .jsonschema import validate as validate_schema
from .memory import MemoryStore, Record
from .model import (
    ROLE_ASSISTANT,
    Message,
    Response,
    ToolCall,
    Usage,
)
from .plugin import parse_manifest
from .policy import PathChecker, PathGrant
from .stream import STREAM_KINDS
from .tool import Registry
from .toolcall import parse_tool_call, strip_tool_call_markup


@dataclass
class VectorFailure:
    vector_id: str
    group: str
    detail: str

    def __str__(self) -> str:
        return f"{self.group}/{self.vector_id}: {self.detail}"


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def run_all(root: Path | None = None) -> list[VectorFailure]:
    root = root or repo_root()
    version = (root / "spec" / "SPEC_VERSION").read_text(encoding="utf-8").strip()
    failures: list[VectorFailure] = []
    seen: dict[str, str] = {}
    for path in sorted((root / "spec" / "vectors").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        group = data.get("group", "")
        if data.get("specVersion") != version:
            failures.append(
                VectorFailure(
                    path.stem,
                    group or path.stem,
                    f"specVersion {data.get('specVersion')!r}, want {version!r}",
                )
            )
        if group != path.stem:
            failures.append(
                VectorFailure(
                    path.stem,
                    group or path.stem,
                    f"group {group!r}, want {path.stem!r}",
                )
            )
        for vector in data.get("vectors", []):
            vector_id = vector.get("id", "")
            if not vector_id:
                failures.append(VectorFailure(path.stem, group, "vector without id"))
                continue
            if vector_id in seen:
                failures.append(
                    VectorFailure(
                        vector_id,
                        group,
                        f"duplicate id also used by {seen[vector_id]}",
                    )
                )
            seen[vector_id] = group
            try:
                run_vector(group, vector)
            except Exception as exc:
                failures.append(
                    VectorFailure(
                        vector_id, group, f"{type(exc).__name__}: {exc}"
                    )
                )
    return failures


def run_vector(group: str, vector: dict[str, Any]) -> None:
    runner = _RUNNERS.get(group)
    if runner is None:
        raise AssertionError(f"no runner for group {group!r}")
    runner(vector)


def _toolcall(vector: dict[str, Any]) -> None:
    inp = vector["input"]
    exp = vector["expect"]
    if inp.get("operation") == "strip":
        got = strip_tool_call_markup(inp.get("content", ""))
        _assert(got == exp.get("text"), f"strip: got {got!r}")
        return
    call = parse_tool_call(inp.get("content", ""))
    if exp.get("nil"):
        _assert(call is None, f"expected nil, got {call!r}")
        return
    _assert(call is not None, "expected a tool call, got nil")
    _assert(call.name == exp.get("name"), f"name: got {call.name!r}")
    _assert(
        call.input == (exp.get("input") or {}),
        f"input: got {call.input!r}",
    )


def _jsonschema(vector: dict[str, Any]) -> None:
    inp = vector["input"]
    exp = vector["expect"]
    errors = validate_schema(inp.get("schema") or {}, inp.get("data"))
    got_paths = sorted(error.path for error in errors)
    want_paths = sorted(exp.get("errorPaths") or [])
    _assert(
        bool(errors) is not bool(exp.get("valid")),
        f"valid: got {not errors}, want {exp.get('valid')}",
    )
    _assert(got_paths == want_paths, f"errorPaths: got {got_paths}, want {want_paths}")


def _plugin(vector: dict[str, Any]) -> None:
    inp = vector["input"]
    exp = vector["expect"]
    raw = inp.get("raw")
    if raw is None:
        raw = json.dumps(inp.get("manifest") or {})
    try:
        manifest = parse_manifest(raw)
    except PluginError:
        manifest = None
    _assert(
        (manifest is not None) is bool(exp.get("valid")),
        f"valid: got {manifest is not None}, want {exp.get('valid')}",
    )
    if manifest is None:
        return
    if exp.get("id"):
        _assert(manifest.id == exp["id"], f"id: got {manifest.id!r}")
    if exp.get("kind"):
        _assert(manifest.kind == exp["kind"], f"kind: got {manifest.kind!r}")


def _memory(vector: dict[str, Any]) -> None:
    asyncio.run(_memory_async(vector))


async def _memory_async(vector: dict[str, Any]) -> None:
    inp = vector["input"]
    exp = vector["expect"]
    store = MemoryStore()
    for item in inp.get("puts", []):
        await store.put(item["session"], Record.from_wire(item["record"]))
    records = await store.search(
        inp.get("session", ""),
        inp.get("query", ""),
        inp.get("limit", 0),
    )
    ids = [record.id for record in records] or None
    contents = [record.content for record in records] or None
    _assert(ids == (exp.get("ids") or None), f"ids: got {ids!r}")
    _assert(
        contents == (exp.get("contents") or None),
        f"contents: got {contents!r}",
    )


def _event(vector: dict[str, Any]) -> None:
    asyncio.run(_event_async(vector))


async def _event_async(vector: dict[str, Any]) -> None:
    inp = vector["input"]
    exp = vector["expect"]
    events = [
        Event(type=event_type, session_id="s1")
        for event_type in inp.get("events", [])
    ]
    sink_name = inp.get("sink", "filter")
    if sink_name in ("", "filter"):
        predicate = None
        if "predicateTypes" in inp:
            allowed = set(inp.get("predicateTypes") or [])
            predicate = lambda event: event.type in allowed
        rec = _RecordingSink()
        sink = FilterSink(rec, predicate)
        for event in events:
            await sink.emit(event)
        got = rec.types or None
        _assert(got == (exp.get("delivered") or None), f"delivered: got {got!r}")
        return
    if sink_name == "multi":
        count = inp.get("sinkCount", 1)
        count = count if count > 0 else 1
        recs = [_RecordingSink() for _ in range(count)]
        sink = MultiSink(recs)
        for event in events:
            await sink.emit(event)
        got = [rec.types or None for rec in recs]
        want = exp.get("perSink") or []
        _assert(got == want, f"perSink: got {got!r}, want {want!r}")
        return
    raise AssertionError(f"unknown sink {sink_name!r}")


def _stream(vector: dict[str, Any]) -> None:
    _assert(
        list(STREAM_KINDS) == (vector["expect"].get("kinds") or []),
        f"kinds: got {list(STREAM_KINDS)!r}",
    )


def _checkpoint(vector: dict[str, Any]) -> None:
    inp = vector["input"]
    exp = vector["expect"]
    allow = Allowlist()
    for name in inp.get("registered", []):
        allow.register(name, lambda: {})
    operation = inp.get("operation", "roundtrip")
    code = exp.get("errorCode")
    if operation == "roundtrip":
        data = allow.marshal(inp.get("type", ""), inp.get("value"))
        got = allow.unmarshal(data)
        _assert(got == exp.get("value"), f"value: got {got!r}")
        return
    try:
        if operation == "marshal":
            allow.marshal(inp.get("type", ""), inp.get("value"))
        elif operation == "unmarshal":
            raw = json.dumps(
                {"type": inp.get("type", ""), "data": inp.get("value")}
            )
            allow.unmarshal(raw)
        else:
            raise AssertionError(f"unknown checkpoint operation {operation!r}")
    except TypeNotAllowedError as exc:
        _assert(code == exc.code, f"errorCode: got {exc.code!r}, want {code!r}")
        return
    _assert(code is None, f"expected error {code!r}, got none")


def _policy(vector: dict[str, Any]) -> None:
    inp = vector["input"]
    exp = vector["expect"]
    with tempfile.TemporaryDirectory(prefix="praxo-policy-") as base:
        for directory in inp.get("makeDirs", []):
            (Path(base) / directory).mkdir(parents=True, exist_ok=True)
        grants: list[PathGrant] = []
        for grant in inp.get("grants", []):
            root = Path(base) / grant["root"]
            root.mkdir(parents=True, exist_ok=True)
            grants.append(PathGrant(str(root), grant["access"]))
        need = inp.get("need", "read")
        target = str(Path(base) / inp.get("target", ""))
        if exp.get("error"):
            try:
                PathChecker(grants).check(target, need)
            except PolicyError:
                return
            raise AssertionError("expected a policy error")
        decision = PathChecker(grants).check(target, need)
        _assert(
            decision.allowed == bool(exp.get("allowed")),
            f"allowed: got {decision.allowed}, want {exp.get('allowed')}",
        )


def _context(vector: dict[str, Any]) -> None:
    inp = vector["input"]
    exp = vector["expect"]
    messages = [Message.from_wire(item) for item in inp.get("messages", [])]
    operation = inp.get("operation")
    if operation == "estimate":
        got = estimate_tokens(messages)
        _assert(got == exp.get("tokens"), f"tokens: got {got}")
        return
    budget_input = inp.get("budget") or {}
    budget = ContextBudget(
        max_tokens=budget_input.get("maxTokens", 0),
        keep_recent=budget_input.get("keepRecent", 0),
    )
    out, ok = budget.compact(messages)
    _assert(ok == bool(exp.get("ok")), f"ok: got {ok}")
    if not ok:
        return
    got_tokens = estimate_tokens(out)
    _assert(got_tokens == exp.get("tokens"), f"tokens: got {got_tokens}")
    wire = [message.to_wire() for message in out]
    _assert(wire == exp.get("messages"), f"messages: got {wire}")


def _agent_loop(vector: dict[str, Any]) -> None:
    asyncio.run(_agent_loop_async(vector))


async def _agent_loop_async(vector: dict[str, Any]) -> None:
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
        _assert(error is not None, "expected an error")
        code = exp.get("errorCode")
        if code:
            _assert(isinstance(error, PraxoError), f"error: got {error!r}")
            _assert(error.code == code, f"errorCode: got {error.code!r}")
    else:
        _assert(error is None, f"unexpected error: {error!r}")

    if result is not None:
        _assert(result.output == exp.get("output", ""), f"output: got {result.output!r}")
        _assert(result.steps == exp.get("steps", 0), f"steps: got {result.steps}")
    _assert(
        counter[0] == exp.get("toolInvocations", 0),
        f"tool invocations: got {counter[0]}",
    )
    got_events = sink.types or None
    _assert(
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


def _assert(condition: bool, detail: str) -> None:
    if not condition:
        raise AssertionError(detail)


_RUNNERS = {
    "toolcall": _toolcall,
    "jsonschema": _jsonschema,
    "plugin": _plugin,
    "memory": _memory,
    "event": _event,
    "stream": _stream,
    "checkpoint": _checkpoint,
    "policy": _policy,
    "context": _context,
    "agent-loop": _agent_loop,
}
