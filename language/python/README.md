# PRAXO-CORE: Python Agent Framework

PRAXO-CORE is a dependency-free Python framework for building tool-using AI
agents. It provides the agent runtime, not a model or hosted service, so you
keep control of your models, tools, storage, and sandboxing.

It is for teams that want a small, explicit agent loop instead of a large
orchestration platform:

- Async-first models, tools, events, and sessions.
- Policy hooks, approvals, path checks, PII redaction, and call limits.
- Context budgets, checkpoints, middleware, and fallback models.
- Streaming, cancellation, and an OpenAI-compatible adapter.
- No runtime dependencies; Python 3.11 or newer.

## Install

```bash
pip install praxo-core==0.2.4
```

For a source checkout:

```bash
pip install ./language/python
```

## Quickstart

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
| Governance | Policy hooks, tool selection, PII middleware, call limits |
| Runtime | Context budgets, checkpoints, events, streaming, cancellation |
| Integration | OpenAI-compatible adapter; bring your own model and tools |

## Contract and status

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation. This package supports `SPEC_VERSION` `0.2.0` and
passes all eleven conformance vector groups. Package version `0.2.4` is
published on PyPI. VFS and plugin hosts are not yet implemented.

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
| `praxo.context` | `ContextBudget`, `ModelSummarizer`, `Offloader`, `load_agents_md` |
| `praxo.middleware` | call limits, fallback, PII, structured output, tool selection |
| `praxo.toolcall` | `parse_tool_call`, `strip_tool_call_markup` |
| `praxo.jsonschema` | `Schema`, `ValidationError` |
| `praxo.plugin` | Manifest v1 parsing and validation |

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
