# PRAXO-CORE Zig Core

Zig 0.17 implementation of the PRAXO-CORE agent contract. The normative
contract is [`spec/`](../../spec/README.md); Go remains the reference
implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.2.0`
- Tier: core
- License: MIT
- Dependencies: Zig standard library only

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/zig/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/zig/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/zig/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: Source

## Scope

`0.2.0` implements all eleven vector groups: toolcall, JSON Schema, plugin,
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

## Release

Tag shape: `zig/v0.2.0` for core; `zig/v0.1.0` remains the wire tag.
