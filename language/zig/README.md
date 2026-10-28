# PRAXO-CORE Zig Core

Zig 0.17 implementation of the PRAXO-CORE agent contract. The normative
contract is [`spec/`](../../spec/README.md); Go remains the reference
implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.2.0`
- Tier: core
- License: MIT
- Dependencies: Zig standard library only

## Scope

`0.2.0` implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. `zig/v0.1.0` remains the wire subset.

## Build and test

```bash
mkdir -p build
zig build-exe src/conformance.zig -O ReleaseSafe -femit-bin=build/conformance
./build/conformance
zig test src/toolcall.zig
zig test src/jsonschema.zig
zig test src/plugin.zig
zig test src/pii_test.zig
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
- `src/conformance.zig` vector runner.
- `api-snapshot.py` and `api/` public API snapshot.

## Release

Tag shape: `zig/v0.2.0` for core; `zig/v0.1.0` remains the wire tag.
