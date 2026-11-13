# PRAXO-CORE: Python Agent Framework

PRAXO-CORE is a dependency-free Python framework for building tool-using AI
agents. It provides the agent runtime, not a model or hosted service, so you
keep control of your models, tools, storage, and sandboxing.

It is for teams that want a small, explicit agent loop instead of a large
orchestration platform:

- Async-first models, tools, events, and sessions.
- Policy hooks, approvals, path checks, PII redaction, and call limits.
- Context budgets, checkpoints, middleware, and fallback models.
- Streaming, cancellation, and OpenAI-compatible, Anthropic, and Gemini
  adapters.
- No runtime dependencies; Python 3.11 or newer.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/python/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/python/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/python/llms.md)
- [Examples](examples/): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [PyPI](https://pypi.org/project/praxo-core/0.6.0/)

## Install

```bash
pip install praxo-core==0.6.0
```

For a source checkout:

```bash
pip install ./language/python
```

## Quickstart

For a complete application with explicit tool scope, policy denial tests, and
virtual-environment package checks, use the
[independent Python consumer](../../docs/getting-started/consumer-python.md).

```python
import asyncio

from praxo.agent import Agent, AgentOptions, Session
from praxo.event import Event
from praxo.model import Message, Response, Usage
from praxo.tool import FuncTool, Registry


class EchoModel:
    async def generate(self, request):
        return Response(message=Message(role="assistant", content="hello"))


class LogSink:
    async def emit(self, event: Event) -> None:
        print(event.to_wire())


async def main() -> None:
    tools = Registry()
    tools.register(FuncTool("echo", "Echo input", lambda args: args))
    agent = Agent(
        AgentOptions(model=EchoModel(), tools=tools, events=LogSink())
    )
    result = await agent.run(Session(id="session-1"), "hi")
    print(result.output, result.steps, result.usage)


asyncio.run(main())
```

## What you get

| Area | Included |
| --- | --- |
| Agent loop | Tool calls, multi-step runs, parallel tools, structured output |
| Governance | Policy hooks, tool selection, PII middleware, call limits, HITL interrupts |
| Runtime | Context budgets, checkpoints, events, streaming, cancellation |
| Integration | OpenAI-compatible (OpenAI, DeepSeek, Kimi), Anthropic, and Gemini adapters; bring your own model and tools |

## Harmovela event sink

`HarmovelaSink` posts lifecycle events to `{base_url}/events` as JSON envelopes
with `spec_version`, `id`, `type`, `source`, `created_at`, and a payload that
merges the event data with `session_id` and `run_id` when present.

```python
from praxo.adapters.harmovela import HarmovelaSink

sink = HarmovelaSink("http://127.0.0.1:8790/aep/api")
agent = Agent(AgentOptions(model=EchoModel(), events=sink))
```

Pass `transport` to run without network access; it receives
`(method, url, headers, body)` and returns `(status, body)`. Limits: the sink
adds no authentication, retries, buffering, acknowledgements, ordering, or
exactly-once delivery. Filter sensitive event data at the caller, and use HTTPS
for remote endpoints.

## MCP client (stdio)

`MCPClient` connects to a local MCP server over newline-delimited JSON-RPC 2.0,
runs the `initialize` / `notifications/initialized` handshake, lists tools with
pagination checks, and calls tools through the Core registry seam.

```python
from praxo.adapters.mcp import MCPClient, MCPServerConfig
from praxo.tool import Registry

config = MCPServerConfig(command="my-mcp-server", args=["--stdio"])
async with MCPClient(config) as client:
    tools = await client.list_tools()
    result = await client.call_tool("search", {"query": "praxo"})

    registry = Registry()
    await client.register_tools(registry)
```

`list_tools()` follows `nextCursor`, preserves `inputSchema` on each `MCPTool`,
and rejects repeated cursors and duplicate names. `call_tool()` returns
`structuredContent` when present, otherwise a text string or an ordered list of
text blocks; `isError` results raise `MCPToolError`. Registering tools does not
bypass policy: the agent still authorizes each `tool.invoke` before calling the
registered adapter. Limits: stdio only; no hosted service, authentication,
sandboxing, schema promotion, resources, prompts, sampling, or server-initiated
requests. Tool output is untrusted. Timeouts send `notifications/cancelled`, but
local cancellation does not prove remote work stopped. MCP failures use `MCP_*`
codes such as `MCP_PROTOCOL`, `MCP_TRANSPORT`, `MCP_HANDSHAKE`, `MCP_TIMEOUT`,
`MCP_PAGINATION`, `MCP_DUPLICATE_TOOL`, `MCP_TOOL_ERROR`, `MCP_RPC`, and
`MCP_CLOSED`; `Registry.specs()` still carries only names and descriptions, so
read `MCPTool.input_schema` when you need the model-facing schema.

## Contract and status

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation. This package supports `SPEC_VERSION` `0.2.0` and
passes all eleven conformance vector groups. Source version `0.7.0` is prepared
in the repository; the latest source tag and PyPI package are `python/v0.6.0`
and `praxo-core==0.6.0`.
VFS and plugin hosts are not yet implemented.

## Requirements

- Python 3.11 or newer
- No runtime dependencies

## Contract Surface

| Module | Contract |
| --- | --- |
| `praxo.model` | `Model`, `Request`, `Response`, messages, tool specs, usage |
| `praxo.tool` | `Tool`, `Registry`, `FuncTool` |
| `praxo.event` | `Event`, `Sink`, `MultiSink`, `FilterSink` |
| `praxo.policy` | `Hook`, `Action`, `Decision`, `PathChecker` |
| `praxo.memory` | `Store`, `Record`, `MemoryStore`, `ContextAssembler` |
| `praxo.checkpoint` | `Checkpoint`, `Allowlist` |
| `praxo.agent` | `Agent`, `AgentOptions`, `Session`, `Result` |
| `praxo.hitl` | `Interrupt`, `InterruptDecision`, approve/edit/reject/respond handlers |
| `praxo.context` | `ContextBudget`, `ModelSummarizer`, `Offloader`, `load_agents_md` |
| `praxo.middleware` | call limits, fallback, PII, structured output, tool selection |
| `praxo.toolcall` | `parse_tool_call`, `strip_tool_call_markup` |
| `praxo.jsonschema` | `Schema`, `ValidationError` |
| `praxo.plugin` | Manifest v1 parsing and validation |
| `praxo.adapters.openaicompat` | OpenAI-compatible adapter and provider presets |
| `praxo.adapters.anthropic` | Anthropic Messages adapter |
| `praxo.adapters.gemini` | Gemini generateContent adapter |
| `praxo.adapters.harmovela` | Harmovela HTTP event sink |
| `praxo.adapters.mcp` | stdio MCP client, tool listing, and registry registration |

Wire codecs preserve the Go names, including `image_url`, `runId`,
`contentBlocks`, and plugin `plugin_id`.

## Conformance

From this directory:

```bash
python conformance/run.py
python -m unittest discover -s tests -v
```

Both commands read `../../spec/vectors/*.json`. A released Core implementation must pass every
vector and keep `spec/parity.md` current.

## API Reference and Build

See [API.md](API.md). Refresh the checked-in symbol snapshot after a public API
change:

```bash
python api-snapshot.py
python api-snapshot.py --check
python api-signatures.py --check
python -m build --wheel --sdist .
```

The name snapshot and signature snapshot are checked independently. The
signature baseline covers class constructors, dataclass fields/defaults,
methods, properties, functions, and exported constants. Both are source-API
gates, not runtime or ABI guarantees.

CI installs the built wheel and sdist into separate clean virtual environments
and runs `tests/installed_smoke.py` from outside the source tree. This verifies
the packaged artifacts, not the checkout. It does not prove PyPI publication or
installation from a package registry.

## License

MIT. See [LICENSE](../../LICENSE).
