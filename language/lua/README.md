# PRAXO-CORE Lua Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This rock is its
native Lua Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, JSON
Schema validation, plugin manifest parsing, and human-in-the-loop interrupt
decisions.

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Lua, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

## Features

- A native Lua 5.4 agent loop with tool registration and dispatch.
- Policy hooks, tool scope, HITL decisions, events, memory, context budgets,
  middleware, checkpoints, and a JSON Schema subset.
- OpenAI-compatible, Anthropic, and Gemini adapters with SSE streaming.
- MCP, OpenTelemetry, Harmovela, retriever, and synchronous delegation seams.
- Caller-provided batch tool dispatch; the Core does not create threads.
- MIT-licensed and Lua standard library only.

## Limits

- Core is an execution framework, not a model provider, hosted agent service,
  crawler, workflow engine, or production sandbox.
- Parallel tools use caller-provided batch callbacks; the Core does not create
  threads.
- Checkpoints are recovery hints, not transactions. Core does not provide
  durable execution, exactly-once effects, or an effect ledger.
- Provider credentials, authentication, retries, and durable state remain
  application-owned.
- Go remains the reference implementation; full Go feature parity is not
  claimed.

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

## Package

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.9.1-1`
- Tier: core
- License: MIT
- Dependencies: Lua standard library only
- LuaRocks page: `praxo-core@0.9.1-1` published with the optional
  OpenAI-compatible adapter. Releases are built and published by
  `.github/workflows/release-lua.yml`

## Registry and Coding-Agent Entry

- Get started, prerequisites, and installation: [language documentation](https://axisvela.github.io/praxo-core/languages/lua/)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples): runnable language-specific examples; see each README for prerequisites and verification.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial): read the scope and validation status; source is not portfolio acceptance.
- Reference applications: no language-specific accepted end-to-end application recorded; see the [tutorial catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/).
- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/lua/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/lua/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/lua/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [LuaRocks](https://luarocks.org/modules/hanhhuiwen/praxo-core)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Get started

Install the published package:

```bash
luarocks install praxo-core 0.9.1-1
```

Then run the smallest deterministic example:

- [Consumer starter](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/consumer): explicit tool scope and a deny check.
- [Live model](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/live-model): connect an OpenAI-compatible endpoint and register `get_time`.

See the [Lua documentation](https://axisvela.github.io/praxo-core/languages/lua/) for the full API and the
[language matrix](https://axisvela.github.io/praxo-core/languages/matrix/) for
current scope.

## Examples

Runnable examples live under [`language/lua/examples`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples).

| Goal | Example |
| --- | --- |
| Install and deny one unsafe call | [consumer](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/consumer) |
| Connect a real model | [live-model](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/live-model) |
| Connect MCP tools | [mcp](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/mcp) |
| Validate structured output | [structured-output](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/structured-output) |
| Stream a response | [streaming](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/streaming) |
| Add identity and policy | [identity-policy](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/identity-policy) |
| Persist checkpoints | [checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/checkpoint) |
| Run behind HTTP | [service](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/service) |
| Approve or edit a tool call | [hitl](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/hitl) |
| Resume a multi-turn session | [session-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/session-checkpoint) |
| Retry transient failures | [retry](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/retry) |
| Add provider fallback | [provider-fallback](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/provider-fallback) |
| Observe agent events | [event-sink](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/event-sink) |

## Install

```bash
luarocks install praxo-core 0.9.1-1
```

## Scope

The Core implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. It includes a public API snapshot and a dependency-free test runner.

Optional agent options add cancellation, stream callbacks, and caller-provided
batch tool dispatch. `batch_invoke` receives the prepared calls and the maximum
parallelism and returns results in order; the Core itself does not create
threads. `praxo.sse.parse` rejects truncated and half-packet streams.

## Build and test

```bash
lua language/lua/conformance/run.lua
python language/lua/api-snapshot.py --check
lua language/lua/tests/run.lua
```

## Quickstart

```lua
package.path = "language/lua/?.lua;lua/?/init.lua;" .. package.path
local agent = require("praxo.agent")
local models = require("praxo.models")

local model = agent.static_model("hello")
local options = agent.agent_options(model)
local result = agent.run_agent(options, models.session({ id = "demo" }), "hello")
print(result.output)
```

Tools register on the options object:

```lua
local registry = agent.tool_registry()
agent.register_tool(registry, agent.func_tool("echo", "Echo arguments", function(arguments)
  return arguments
end))
options.tools = registry
options.max_steps = 8
```

## Model Adapters

- `praxo.adapters.openai_compatible` for OpenAI, DeepSeek, Kimi/Moonshot, and
  other OpenAI-compatible endpoints.
- `praxo.adapters.anthropic` for the Anthropic Messages API, including `stream` SSE reassembly.
- `praxo.adapters.gemini` for the Gemini generateContent API.

Each adapter accepts an injectable `transport` function for deterministic tests.
`openai_compatible` also exposes `stream(request, on_delta)`, which sets
`stream: true`, parses SSE, reassembles content, fragmented tool calls, usage,
and `finish_reason`, and calls the delta callback. Inject `stream_transport` to
return raw SSE text; set `on_delta` on the agent options to use it.

## MCP Client

praxo.adapters.mcp implements MCP initialize, paginated tool listing, and
tool calls over an injected transport callback.

## Harmovela Event Sink

`praxo.adapters.harmovela_sink` posts each event to `{base_url}/events`.
The old `praxo.harmovela_sink` path remains as a compatibility wrapper.

```lua
local harmovela = require("praxo.adapters.harmovela_sink")
options.events = harmovela.new({
  base_url = "http://127.0.0.1:8790/aep/api",
})
```

A 2xx status is success; any other status raises `HARMOVELA_HTTP` with the
status and a bounded body. Inject `transport` (and `clock`) to test without a
network. The sink adds no authentication, retries, buffering, ordering, or
exactly-once delivery. Use HTTPS and filter sensitive event data first.

## Layout

- `praxo/` package source.
- `conformance/run.lua` vector runner.
- `api-snapshot.py` and `api/` public API snapshot.
- `tests/run.lua` test suite.

## Release

Tag shape: `lua/v0.9.1`. The tag targets `SPEC_VERSION` `0.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.


## Tutorials and Reference Applications

Language-specific scenario tutorials and reference applications for Lua.

### Scenario Tutorials

| Tutorial | What it shows |
| --- | --- |
| [aquaculture-water](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/aquaculture-water) | A bounded first slice of AE-03, not a pond-control system. It computes fixed oxygen and temperature indicators and drafts a review-only bounded action. No aerator or feeder comm... |
| [host-embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding) | A native Lua Core tutorial for embedding an Agent inside an existing host. The host receives a device event, exposes two fixed callbacks, and receives a review-only report. It d... |
| [irrigation-plan](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/irrigation-plan) | A bounded first slice of IN-06, not an irrigation controller. It evaluates fixed soil/weather observations and drafts a review-only bounded irrigation request. No valve command,... |
| [live-show](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/live-show) | A bounded first slice of MD-07, not a live-stream controller. It replays fixed synthetic engagement events and drafts a review-only presentation order. No audience profiling, co... |
| [storyboard-previs](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/storyboard-previs) | A bounded first slice of MD-01, not a virtual-production pipeline. It reads one fixed script scene, drafts a review-only shot plan and records zero renders and zero engine calls... |
| [world-economy](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/world-economy) | A bounded first slice of MD-03, not an open-world simulation engine. It reads a fixed synthetic world economy at one tick and drafts a review-only balance with no applied change... |

Index: [language/lua/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial).

### Reference Applications

No accepted end-to-end reference application is recorded for this language yet. Candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).

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

