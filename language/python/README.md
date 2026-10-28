# PRAXO-CORE Python SDK

Python implementation of the PRAXO-CORE contract. The normative contract is
[`spec/`](../../spec/README.md); Go remains the reference implementation.

**Status:** Core plus streaming, context management, middleware, and an
OpenAI-compatible adapter. The package passes all eleven conformance vector
groups.
VFS and plugin hosts are not yet implemented. Wheel and sdist builds are
verified; PyPI publication is pending. Use the source installation below.

Package version: `0.2.0`. Supported contract: `SPEC_VERSION` `0.2.0`
(`praxo.SPEC_VERSION`).

## Requirements

- Python 3.11 or newer
- No runtime dependencies

## Install

```bash
pip install ./language/python
```

## Usage

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

Both commands read `../../spec/vectors/*.json`. A released SDK must pass every
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
