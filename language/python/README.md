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

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Python, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

## Get started

Install the published package:

```bash
pip install praxo-core==0.11.2
```

Then run the smallest deterministic example:

- [Consumer starter](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/consumer): explicit tool scope and a deny check.
- [Live model](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/live-model): connect an OpenAI-compatible endpoint and register `get_time`.

See the [Python documentation](https://axisvela.github.io/praxo-core/languages/python/) for the full API and the
[language matrix](https://axisvela.github.io/praxo-core/languages/matrix/) for
current scope.

## Examples

Runnable examples live under [`language/python/examples`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples).

| Goal | Example |
| --- | --- |
| Install and deny one unsafe call | [consumer](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/consumer) |
| Connect a real model | [live-model](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/live-model) |
| Connect MCP tools | [mcp](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/mcp) |
| Validate structured output | [structured-output](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output) |
| Stream a response | [streaming](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/streaming) |
| Add identity and policy | [identity-policy](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/identity-policy) |
| Persist checkpoints | [checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/checkpoint) |
| Run behind HTTP | [service](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service) |
| Run behind HTTP with verified identity | [service-auth](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service-auth) |
| Approve or edit a tool call | [hitl](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/hitl) |
| Resume a multi-turn session | [session-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/session-checkpoint) |
| Retry transient failures | [retry](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/retry) |
| Add provider fallback | [provider-fallback](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/provider-fallback) |
| Observe agent events | [event-sink](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/event-sink) |

## Tutorials and Reference Applications

Scenario tutorials are bounded teaching slices. Reference applications are
portfolio integrations whose end-to-end acceptance remains in the roadmap.

### Scenario Tutorials

| Scenario | Tutorial |
| --- | --- |
| Audiobook production | [audiobook-production](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/audiobook-production) |
| AE-05 Biodiversity alerts | [biodiversity-alerts](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/biodiversity-alerts) |
| SE-02 Bug repair | [bug-repair](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/bug-repair) |
| HC-05 CBT exercise | [cbt-exercise](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/cbt-exercise) |
| HC-01 Clinical guidelines | [clinical-guidelines](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/clinical-guidelines) |
| FC-03 Credit diligence | [credit-diligence](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/credit-diligence) |
| MD-04 Dubbing plan | [dubbing-plan](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/dubbing-plan) |
| Education tutoring | [education-tutoring](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/education-tutoring) |
| Insurance claims | [insurance-claims](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/insurance-claims) |
| Legal compliance | [legal-compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance) |
| Literature review | [literature-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/literature-review) |
| Litigation timeline | [litigation-timeline](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/litigation-timeline) |
| Marketing segments | [marketing-segments](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/marketing-segments) |
| SC-02 Molecule screen | [molecule-screen](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/molecule-screen) |
| Negotiation interpretation | [negotiation-interpretation](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/negotiation-interpretation) |
| Office Q&A | [office-qa](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa) |
| Order review | [order-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review) |
| LJ-02 Patent FTO | [patent-fto](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/patent-fto) |
| Pentest lab review | [pentest-lab-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/pentest-lab-review) |
| CY-04 Phishing awareness | [phishing-awareness](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/phishing-awareness) |
| CT-05 Pollution tracing | [pollution-tracing](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/pollution-tracing) |
| LJ-04 Precedent outline | [precedent-outline](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/precedent-outline) |
| OP-05 Recruiting match | [recruiting-match](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/recruiting-match) |
| Threat hunting | [threat-hunting](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/threat-hunting) |
| HC-03 Trial screening | [trial-screening](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/trial-screening) |
| OG-07 Virtual PI | [virtual-pi](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/virtual-pi) |

Index: [language/python/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial).

### Reference Applications

No accepted end-to-end reference application is recorded for Python yet.
Candidate goals are tracked in the
[reference application portfolio](https://github.com/axisvela/praxo-core/blob/main/docs/project/planning/roadmap.md#reference-application-portfolio).

Planning context: [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/), [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), and [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/). Chinese: [教程计划](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/), [候选场景](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/), [教程目录](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/).

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- GitHub Issues: <https://github.com/axisvela/praxo-core/issues>
- Documentation: <https://axisvela.github.io/praxo-core/>
- Architect: <https://axisvela.architect.pub>


## Registry and Coding-Agent Entry

- Get started, prerequisites, and installation: [language documentation](https://axisvela.github.io/praxo-core/languages/python/)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/python/examples): runnable language-specific examples; see each README for prerequisites and verification.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial): read the scope and validation status; source is not portfolio acceptance.
- Reference applications: no language-specific accepted end-to-end application recorded; see the [tutorial catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/).
- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/python/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/python/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/python/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [PyPI](https://pypi.org/project/praxo-core/0.11.2/)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Install

```bash
pip install praxo-core==0.11.2
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
passes all eleven conformance vector groups. The latest source tag is
`python/v0.11.2`; the published PyPI package is `praxo-core==0.11.2`.
VFS is not yet implemented; see the support policy for current scope.

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


## Process plugin host

`praxo.ProcessHost` speaks the framework JSON-Lines process plugin contract
with token authentication, health handshake, invocation timeout, cancellation,
and typed call errors. See `docs/guides/plugins.md`.

## License

MIT. See [LICENSE](../../LICENSE).
