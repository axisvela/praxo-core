# PRAXO-CORE Swift Core

Swift implementation of the PRAXO-CORE contract.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.2.0`
- Tier: core
- License: MIT

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/swift/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/swift/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/swift/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Swift Package Index](https://swiftpackageindex.com/axisvela/praxo-core-swift)

## Scope

`0.2.0` implements all eleven conformance vector groups: tool-call parsing, JSON
Schema, plugin manifests, memory, events, stream kinds, checkpoint envelopes,
path policy, context budgets, middleware, and the agent loop. It also includes
non-streaming OpenAI-compatible, Anthropic, and Gemini model adapters.

## Install

```swift
.package(url: "https://github.com/axisvela/praxo-core-swift.git", from: "0.2.0")
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
provider HTTP errors (`PROVIDER_HTTP`). Streaming is not implemented.

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

## Layout

- `Sources/PraxoCore/` library.
- `Sources/PraxoConformance/` wire and core vector runner.
- `api-snapshot.py` and `api/` public API snapshot.
- `Tests/PraxoCoreTests/` XCTest coverage.

## Release

Tag shape: `swift/v0.2.0`. The tag targets `SPEC_VERSION` `0.2.0`. SPM and
Swift Package Index consumption require a split repository with root
`Package.swift` and plain semver tags; see [PUBLISHING.md](PUBLISHING.md).
