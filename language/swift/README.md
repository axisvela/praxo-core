# PRAXO-CORE Swift Core

Swift implementation of the PRAXO-CORE contract.

## Features

- A native Swift agent loop with tool registration and dispatch.
- Policy hooks, tool scope, HITL approve/edit/reject/respond decisions, events,
  memory, checkpoints, and context budgets.
- OpenAI-compatible, Anthropic, and Gemini adapters with streaming and an
  injectable transport.
- MCP, OpenTelemetry, Harmovela, retriever, and synchronous delegation seams.
- XCTest coverage, an API snapshot, and a conformance runner.
- MIT-licensed and dependency-free.

## Limits

- Core is an execution framework, not a model provider, hosted agent service,
  crawler, workflow engine, or production sandbox.
- Checkpoints are recovery hints, not transactions. Core does not provide
  durable execution, exactly-once effects, or an effect ledger.
- Provider credentials, authentication, retries, and durable state remain
  application-owned.
- MCP uses caller-supplied transports; no remote MCP service is bundled.
- The split package `0.7.2` is documentation-only and non-streaming; SSE
  streaming is available in source tag `swift/v0.9.0`, not in the split package.
- Go remains the reference implementation; full Go feature parity is not
  claimed.

## Package

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.9.0`
- Tier: core
- License: MIT

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/swift/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/swift/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/swift/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/swift/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Swift Package Index](https://swiftpackageindex.com/axisvela/praxo-core-swift)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Examples

Fifteen runnable examples ship under [`language/go/examples/`](examples):

| Example | What it shows |
| --- | --- |
| [consumer](language/go/examples/consumer) | Deterministic model, one tool, and allow/deny policy |
| [live-model](language/go/examples/live-model) | OpenAI-compatible endpoint and a `get_time` tool |
| [structured-output](language/go/examples/structured-output) | Final JSON answer validation and rejection |
| [identity-policy](language/go/examples/identity-policy) | Trusted principal, role/tenant denial |
| [service](language/go/examples/service) | Transport-neutral HTTP request handler |
| [checkpoint](language/go/examples/checkpoint) | Allowlisted checkpoint payload round trip |
| [session-checkpoint](language/go/examples/session-checkpoint) | Multi-turn history continuation |
| [event-sink](language/go/examples/event-sink) | Sink fan-out and tool-only filtering |
| [retry](language/go/examples/retry) | Bounded retry and exhausted failure |
| [provider-fallback](language/go/examples/provider-fallback) | Primary/fallback model selection |
| [streaming](language/go/examples/streaming) | Streamed chunk accumulation |
| [mcp](language/go/examples/mcp) | Caller-owned in-process MCP transport |
| [hitl](language/go/examples/hitl) | Approval, edit, and final-argument reauthorization |
| [representative-chain](language/go/examples/representative-chain) | MCP, policy, delegation, OTel/Harmovela, and denied-edit chain |
| [advanced-delegation](language/go/examples/advanced-delegation) | Six application-level delegation governance checks |

Each example has its own README with the exact `swift run` command. They are
deterministic local checks, not live-provider or production evidence.

## Scope

`0.8.0` implements all eleven conformance vector groups: tool-call parsing, JSON
Schema, plugin manifests, memory, events, stream kinds, checkpoint envelopes,
path policy, context budgets, middleware, HITL interrupt decisions, and the
agent loop. It also includes
streaming OpenAI-compatible and Anthropic plus streaming Gemini model adapters, MCP
transport seams, Harmovela, OpenTelemetry, retriever, and synchronous delegation
seams.

## Install

```swift
.package(url: "https://github.com/axisvela/praxo-core-swift.git", from: "0.7.1")
```

## Build and test

```bash
swift test
swift run praxo-conformance
python api-snapshot.py --check
```

CI runs all three on macOS. The package has no external dependencies.

## OpenAI-Compatible Adapter

`OpenAICompatibleModel` maps Core requests to `POST {baseUrl}/chat/completions`,
including messages, tools, tool choice, assistant tool calls, token usage, and
provider HTTP errors (`PROVIDER_HTTP`). `generateStream` sets `stream: true`, parses SSE, reassembles content, fragmented tool calls, usage, and finish reason, and calls the delta callback. Set `AgentOptions.onDelta` to use it.

```swift
let config = OpenAICompatibleConfig(
    baseURL: "https://api.example.com/v1",
    model: "provider-model-id",
    apiKey: "secret"
)
let model = OpenAICompatibleModel(config)
let response = try model.generate(
    Request(messages: [Message.text(Roles.user, "hello")])
)
```

`URLSessionTransport` is the production transport. Inject a `ProviderTransport`
fake in tests to avoid network calls.

## Anthropic and Gemini Adapters

`AnthropicModel` posts to `{baseURL}/v1/messages` with `x-api-key` and
`anthropic-version`. `GeminiModel` posts to
`{baseURL}/v1beta/models/{model}:generateContent` with `x-goog-api-key`. Both
map system messages, tools, tool calls, tool results, usage, and provider HTTP
errors over the injected `ProviderTransport`. Streaming is not implemented.

```swift
let claude = AnthropicModel(
    AnthropicConfig(model: "claude-sonnet-4-5", apiKey: "secret")
)
let gemini = GeminiModel(
    GeminiConfig(model: "gemini-2.5-pro", apiKey: "secret")
)
```

## Harmovela Event Sink

`HarmovelaSink` posts Core events to `POST {baseURL}/events` with the documented
envelope (`spec_version`, `id`, `type`, `source`, `created_at`, `payload`). Its
throwing `emit` surfaces transport and HTTP failures; the non-throwing
`EventSink` callback can wrap it when errors are handled elsewhere.

```swift
let sink = HarmovelaSink(baseURL: "http://127.0.0.1:8790/aep/api")
try sink.emit(Event(type: "tool.call", sessionID: "s1", runID: "run-1",
                    data: ["name": "echo"]))
```

`HarmovelaTransport` accepts any 2xx response and rejects other statuses with
`HARMOVELA_HTTP` plus a 512-character body limit. Inject a fake transport and a
`HarmovelaTimestamp` clock in tests. The sink has no authentication, retries,
buffering, ordering, or exactly-once guarantee; filter sensitive event data
caller-side and use HTTPS for remote endpoints.

## OpenTelemetry, Retriever, and Delegation Seams

`OtelSink` maps Core events to OTLP/HTTP spans over an injected
`OtelTransport`. Event data is excluded unless its key is allowlisted in
`allowedDataKeys`; non-2xx responses raise `OTEL_HTTP`.

`FuncRetriever` and `retrieveDocuments` provide a document/query/limit seam.
`SubagentManager` runs a caller-supplied `SubagentRunner` synchronously and
returns a terminal `SubagentTask`; it does not provide an asynchronous manager,
durable queue, or cross-process worker.

## Process plugin host

`PluginProcessHost` speaks the framework JSON-Lines process plugin protocol with
token authentication, health handshake, invocation timeout, and typed errors.
## Layout

- `Sources/PraxoCore/` library.
- `Sources/PraxoConformance/` wire and core vector runner.
- `api-snapshot.py` and `api/` public API snapshot.
- `Tests/PraxoCoreTests/` XCTest coverage.

## Release

Tag shape: `swift/v0.8.0`. The tag targets `SPEC_VERSION` `0.2.0`. SPM and
Swift Package Index consumption require a split repository with root
`Package.swift` and plain semver tags; see [PUBLISHING.md](PUBLISHING.md).

## Tutorials and Reference Applications

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the reference-application portfolio.
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and application paths.
- [Reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio) ([中文](https://axisvela.github.io/praxo-core/zh-CN/project/roadmap/)).
- Language tutorials: [language/swift/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/swift/Tutorial).

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

