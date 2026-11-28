# PRAXO-CORE Julia Core

Julia implementation of the PRAXO-CORE AI agent framework contract.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.9.0`
- Tier: core
- License: MIT
- Dependency: JSON.jl

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Julia, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

## Install

General registry merge is pending; no registry package is published. From the
repository root, use the source checkout:

```julia
using Pkg
Pkg.develop(path="language/julia")
```

## Registry and Coding-Agent Entry

- Get started, prerequisites, and installation: [language documentation](https://axisvela.github.io/praxo-core/languages/julia/)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/julia/examples): runnable language-specific examples; see each README for prerequisites and verification.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial): read the scope and validation status; source is not portfolio acceptance.
- [Reference applications](https://github.com/axisvela/praxo-core/tree/main/language/julia/application): read the scope and validation status; source is not portfolio acceptance.
- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/julia/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/julia/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/julia/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Julia General (pending)](https://github.com/axisvela/praxo-core-Julia)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Scope

`0.8.0` implements all eleven conformance vector groups: tool-call parsing, JSON
Schema, plugin manifests, memory, events, stream kinds, checkpoint envelopes,
path policy, context budgets, middleware, and the agent loop.
OpenAI-compatible and Anthropic and Gemini streaming model
adapters, an OpenTelemetry event sink, and the `PluginProcess` process host are
available under `src/adapters/` and `src/PluginProcess.jl`.

## OpenAI-Compatible Adapter

`OpenAICompatibleModel` implements the native `AbstractModel` seam. It posts to
`{base_url}/chat/completions` and maps assistant content, tool calls, and token
usage. Supply `transport` to run without network access; it receives
`(path, payload)` and returns decoded JSON.

```julia
adapter = openai_compatible("https://api.example.com/v1", "model-id";
                            api_key = "token")
result = generate(adapter, Request([Message(Roles.USER, "hi")]))
```

Provider HTTP failures raise `PraxoError` with code `PROVIDER_HTTP`; invalid
tool-argument JSON raises `PROVIDER_JSON`. `generate_stream` sets `stream: true`,
parses SSE, reassembles content, fragmented tool calls, usage, and
`finish_reason`, and calls the delta callback. Inject `stream_transport`
returning raw SSE text; set `on_delta` in `AgentOptions` to use it.

## Anthropic and Gemini Adapters

`AnthropicModel` and `GeminiModel` implement the native `AbstractModel` seam for
the Messages and generateContent APIs. Both accept `transport` receiving
`(path, payload)` and return decoded JSON.

```julia
claude = anthropic("https://api.anthropic.com", "claude-sonnet-4-5"; api_key = "ak")
gemini_model = gemini("https://generativelanguage.googleapis.com", "gemini-2.5-pro"; api_key = "gk")
```

## Harmovela Event Sink

`harmovela_sink` implements the native `AbstractSink` seam. It posts each event
to `POST {base_url}/events` with the documented envelope. Supply `transport` to
run without network access; it receives `(path, body, headers)` and returns a
named tuple with `status` and `body`. Supply `clock` to return `(seconds,
nanos)` for deterministic ids and timestamps.

```julia
sink = harmovela_sink("http://127.0.0.1:8790/aep/api";
                      source = "praxo-core", spec_version = "0.2")
options = AgentOptions(model)
options.events = sink
```

A 2xx status is success. Other statuses raise `PraxoError` with code
`HARMOVELA_HTTP`; a missing base URL raises `HARMOVELA_URL`. The sink adds no
authentication, retries, buffering, ordering, or exactly-once delivery. Use
HTTPS and caller-side filtering for sensitive event data.

## OpenTelemetry Event Sink

`otel_sink` implements the native `AbstractSink` seam and posts OTLP/HTTP spans
to the caller-supplied endpoint. Supply `transport` to run without network
access; it receives `(endpoint, body, headers)` and returns a named tuple with
`status` and `body`. Supply `clock` to return `(seconds, nanos)` for
deterministic ids and timestamps.

```julia
sink = otel_sink(
    "http://127.0.0.1:4318/v1/traces";
    service_name = "praxo-core",
    allowed_data_keys = ["name"],
)
options.events = sink
```

Event data is excluded unless its keys appear in `allowed_data_keys`. Trace and
span IDs are deterministic; a missing endpoint raises `OTEL_URL`. A 2xx status
is success. Other statuses raise `PraxoError` with code `OTEL_HTTP` and a
bounded response body. No OpenTelemetry SDK is required.

## Retriever

`Document`, `Retriever`, `FuncRetriever`, and `retrieve_documents` form the
retriever seam. A retriever is a function receiving `(query, limit)` and
returning documents.

```julia
retriever = func_retriever(
    (query, limit) -> [Document("doc-1", query, Dict("source" => "test"), 0.5)],
)
documents = retrieve_documents(retriever, "query", 5)
```

A negative limit raises `PraxoError` with code `RETRIEVER_INVALID`.

## Delegation

`subagent_run` invokes a `SubagentRunner` synchronously and returns a terminal
`SubagentTask` with `completed` or `failed` status. A `PraxoError` code is
preserved in `task.error`; other failures use `SUBAGENT_ERROR`.

```julia
request = subagent_request("parent", "child", "prompt")
task = subagent_run(
    request -> subagent_result(agent_id = request.agent_id, output = "done"),
    request,
)
```

An empty parent session or agent ID raises `PraxoError` with code
`SUBAGENT_INVALID`.

## Human-in-the-Loop Approval

`AgentOptions` accepts `interrupt_on`, `on_interrupt_decision`, and
`on_interrupt` to pause matching tool calls. The agent checks allowed tools,
runs the initial policy, applies before-tool middleware, and then applies the
interrupt before `tool.call` and `invoke`.

```julia
options = AgentOptions(model;
    interrupt_on = ["write_note"],
    on_interrupt_decision = interrupt -> InterruptDecision(
        INTERRUPT_EDIT;
        arguments = Dict{String,Any}("text" => "hello", "visibility" => "private"),
    ))
```

Decisions are `approve` (continue), `edit` (replace arguments and reauthorize),
`reject` (raise `AGENT_APPROVAL_DENIED` with the reason), and `respond` (skip
the tool and use the response). A matching call with no handler raises
`AGENT_INTERRUPT_UNHANDLED`; an unknown action or edit without arguments raises
`AGENT_INTERRUPT_DECISION_INVALID`. See [`language/go/examples/hitl`](language/go/examples/hitl/).

## Build and test

```bash
julia --project=language/julia -e 'using Pkg; Pkg.instantiate()'
julia --project=language/julia language/julia/conformance/run.jl
julia --project=language/julia language/julia/api-snapshot.jl --check
julia --project=language/julia language/julia/test/runtests.jl
```

Local toolchain used by the repository maintainers lives at `D:\dev\julia`.

## Layout

- `src/` package source.
- `conformance/run.jl` vector runner.
- `api-snapshot.jl` and `api/` public API snapshot.
- `test/runtests.jl` Julia test suite.

## Release

Tag shape: `julia/v0.8.0`. The tag targets `SPEC_VERSION` `0.2.0`. The mirror `axisvela/praxo-core-Julia` registers the package through
JuliaRegistrator; see [PUBLISHING.md](PUBLISHING.md).


## Tutorials and Reference Applications

Language-specific scenario tutorials and reference applications for Julia.

### Scenario Tutorials

| Tutorial | What it shows |
| --- | --- |
| [airport-recovery](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/airport-recovery) | Simulate fixed gate, crew and connection constraints. No production write or external system access. |
| [churn-warning](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/churn-warning) | Compute fixed risk signals and draft a consent-aware retention offer. No production write or external system access. |
| [dispatch-review](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/dispatch-review) | A bounded energy-dispatch planning tutorial. It enumerates a small two-source integer dispatch, calculates cost and unmet demand, and lets Core choose a plan-review or shortfall... |
| [eda-placement](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/eda-placement) | Explore a fixed placement grid and report PPA proxies. No production write or external system access. |
| [emergency-route-plan](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/emergency-route-plan) | Simulate fixed closures and constrained relief routes. No production write or external system access. |
| [experiment-comparison](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison) | A native Julia analytics tutorial. The Agent has one fixed tool, `compare_experiments`, which computes means and a delta over fixed baseline and candidate results. The determini... |
| [fire-spread](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/fire-spread) | Replay fixed weather and fuel cells and compare modeled spread. No production write or external system access. |
| [hedge-plan](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/hedge-plan) | Simulate fixed crop exposure and compare scenario costs. No production write or external system access. |
| [hvac-settings](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/hvac-settings) | Simulate fixed occupancy and thermal constraints. No production write or external system access. |
| [lab-loop](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/lab-loop) | Simulate a fixed cycle and draft review-only next parameters. No production write or external system access. |
| [materials-design](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/materials-design) | Evaluate fixed candidate properties and draft the next simulation. No production write or external system access. |
| [mesh-review](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/mesh-review) | Compare fixed mesh descriptors against stated constraints. No production write or external system access. |
| [molecule-screen](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/molecule-screen) | Rank fixed synthetic descriptors and draft a review. No production write or external system access. |
| [ocean-routing](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/ocean-routing) | Compare fixed route/weather costs and draft a route. No production write or external system access. |
| [policy-simulation](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/policy-simulation) | Simulate a small synthetic population and report sensitivity. No production write or external system access. |
| [traffic-signal-plan](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/traffic-signal-plan) | Simulate fixed junction queues and verify timing against limits. No production write or external system access. |
| [virtual-pi](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/virtual-pi) | Coordinate fixed literature, simulation and review tasks with provenance. No production write or external system access. |
| [waste-collection](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/waste-collection) | Replan a fixed collection queue under vehicle limits. No production write or external system access. |
| [wealth-analysis](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/wealth-analysis) | Compute fixed statement ratios and cite assumptions. No production write or external system access. |

Index: [language/julia/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial).

### Reference Applications

No accepted end-to-end reference application is recorded for this language yet. Candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/planning/roadmap/#reference-application-portfolio).

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

