# PRAXO-CORE Python SDK

Python implementation of the PRAXO-CORE contract. The normative contract is
[`spec/`](../spec/README.md); Go remains the reference implementation.

**Status:** Phase 1 core plus streaming and an OpenAI-compatible adapter. The
package passes all nine conformance vector groups. Context budgets, middleware,
VFS, and plugin hosts are not yet implemented.

## Requirements

- Python 3.11 or newer
- No runtime dependencies

## Install

```bash
pip install ./python
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

Both commands read `../spec/vectors/*.json`. A released SDK must pass every
vector and keep `spec/parity.md` current.

## License

MIT. See [LICENSE](../LICENSE).
