# PRAXO-CORE Zig Core

Zig 0.17 implementation of the PRAXO-CORE agent contract. The normative
contract is [`spec/`](../../spec/README.md); Go remains the reference
implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.5.0`
- Tier: core
- License: MIT
- Dependencies: Zig standard library only

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/zig/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/zig/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/zig/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/zig/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: Source

## Scope

`0.5.0` implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. `zig/v0.1.0` remains the wire subset.

## Harmovela Event Sink

```zig
const harmovela = @import("harmovela.zig");

var sink = harmovela.Sink.init(allocator, "http://127.0.0.1:8790/aep/api");
sink.transport = injected_transport;
try sink.emit(.{
    .type = "tool.call",
    .session_id = "s1",
    .run_id = "run-1",
    .data = .{ .object = payload },
});
```

`Sink.emit` posts to `{baseUrl}/events` with `content-type: application/json`
and the documented `spec_version`, `id`, `type`, `source`, `created_at`, and
merged `payload` envelope. Inject a `Transport` and `Clock` to avoid network
access in tests. A 2xx status is success; any other status returns
`SinkError.HarmovelaHttp` and stores a bounded message in `last_error` with the
status and response body.

The sink adds no authentication, retries, buffering, ordering, or
exactly-once-delivery guarantee. Apply caller-side filtering because event data
may contain sensitive content, and use HTTPS for remote endpoints. The default
transport uses `std.http`.

## OpenTelemetry Sink

```zig
const otel = @import("otel.zig");

var sink = otel.Sink.init(allocator, "http://127.0.0.1:4318/v1/traces");
sink.allowed_data_keys = &.{"name"};
sink.transport = injected_transport;
try sink.emit(.{ .type = "tool.call", .session_id = "s1" });
```

`Sink.emit` posts an OTLP/HTTP span with deterministic 32-character trace and
16-character span IDs over a caller-supplied `Transport`. Event data is excluded
unless a key is listed in `allowed_data_keys`. A 2xx status is success; any
other status returns `OtelError.OtelHttp` and stores a bounded message in
`last_error`. An empty endpoint returns `OtelError.OtelEndpointRequired`
(`OTEL_URL`). The sink does not import or depend on an OpenTelemetry SDK.

## Retriever

```zig
const retriever = @import("retriever.zig");

const documents = try retriever.retrieveDocuments(
    allocator,
    .{ .ctx = context, .retrieveFn = retrieveFn },
    "query",
    5,
);
```

`Document` carries an id, content, metadata, and score. The retriever seam takes
a query and limit; a negative limit returns
`RetrieverError.RetrieverInvalid` (`RETRIEVER_INVALID`).

## Subagent Delegation

```zig
const delegation = @import("delegation.zig");

const task = try delegation.subagentRun(
    allocator,
    .{ .ctx = context, .runFn = runFn },
    .{ .parent_session_id = "parent", .agent_id = "child", .prompt = "look up" },
    null,
);
```

`subagentRun` is synchronous. It returns a terminal `SubagentTask` with
`completed` or `failed` status, and a failed task preserves the runner error
code. Empty parent session or agent IDs return
`SubagentError.SubagentInvalid` (`SUBAGENT_INVALID`). This seam does not provide
an asynchronous manager, queues, cancellation, or durable workers.

## Build and test

```bash
mkdir -p build
zig build-exe src/conformance.zig -O ReleaseSafe -femit-bin=build/conformance
./build/conformance
zig test src/toolcall.zig
zig test src/jsonschema.zig
zig test src/plugin.zig
zig test src/pii_test.zig
zig test src/openaicompat_test.zig
zig test src/harmovela_test.zig
zig test src/otel_test.zig
zig test src/retriever_test.zig
zig test src/delegation_test.zig
python api-snapshot.py --check
```

On Windows, copy or emit the binary with an `.exe` suffix before running it.

## Layout

- `src/json.zig` JSON helpers.
- `src/models.zig` model, tool, event, and result types.
- `src/toolcall.zig` tool-call parsing and markup stripping.
- `src/jsonschema.zig` documented JSON Schema subset.
- `src/plugin.zig` Manifest v1 validation.
- `src/runtime.zig` memory, events, checkpoint, policy, and context.
- `src/middleware.zig` PII, structured output, call limits, tool selection,
  and fallback.
- `src/agent.zig` agent loop and registry.
- `src/otel.zig` OTLP/HTTP OpenTelemetry sink over an injected transport.
- `src/retriever.zig` document retriever seam.
- `src/delegation.zig` synchronous subagent delegation seam.
- `src/openaicompat.zig` non-streaming OpenAI-compatible adapter.
- `src/conformance.zig` vector runner.
- `api-snapshot.py` and `api/` public API snapshot.

## OpenAI-Compatible Adapter

`openaicompat.Adapter` posts to `{baseURL}/chat/completions`, maps assistant
content, tool calls, usage, and finish reason, and parses tool arguments into
JSON objects. It uses `std.http` and accepts an injected `Transport` for
deterministic tests. Missing base URLs and non-2xx responses return
`ProviderError.ProviderHttp`; invalid tool arguments return
`ProviderError.ProviderJson`. `providerCode` maps errors to `PROVIDER_HTTP` and
`PROVIDER_JSON`. Streaming is not implemented.

```zig
var adapter = openaicompat.Adapter.init(allocator, "https://api.openai.com/v1", "gpt-4o-mini");
adapter.api_key = api_key;
const model = adapter.asModel();
const result = try agent.runAgent(allocator, .{ .model = model }, .{ .id = "s1" }, "Hi");
```

## Anthropic and Gemini Adapters

`anthropic.Adapter` and `gemini.Adapter` provide native Messages and
generateContent mappings over the same injectable `Transport` seam. They map
tool calls, tools schemas, usage, finish reasons, and provider errors.

```zig
var claude = anthropic.Adapter.init(allocator, "https://api.anthropic.com", "claude-sonnet-4-5");
claude.api_key = anthropic_key;
var gemini_model = gemini.Adapter.init(allocator, "https://generativelanguage.googleapis.com", "gemini-2.5-pro");
gemini_model.api_key = gemini_key;
```

## Release

Tag shape: `zig/v0.5.0` for core; `zig/v0.1.0` remains the wire tag.
