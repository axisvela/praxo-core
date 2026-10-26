# PRAXO-CORE Zig SDK

Zig 0.17 implementation of the PRAXO-CORE wire contract. The normative contract
is [`spec/`](../spec/README.md); Go remains the reference implementation.

- `SPEC_VERSION`: `0.2.0`
- SDK version: `0.1.0`
- Tier: wire (toolcall, JSON Schema, plugin manifest)
- License: MIT
- Dependencies: Zig standard library only

## Scope

`0.1.0` implements the wire subset: tool-call parsing/stripping, the documented
JSON Schema subset, and plugin manifest validation. The core agent loop and
provider adapters are follow-up work.

## Build and test

```bash
zig build-exe src/conformance.zig -O ReleaseSafe -femit-bin=build/conformance
./build/conformance
zig test src/toolcall.zig
zig test src/jsonschema.zig
zig test src/plugin.zig
python api-snapshot.py --check
```

On Windows, run `build/conformance.exe` after copying or emitting with an
`.exe` suffix.

## Layout

- `src/json.zig` JSON helpers.
- `src/toolcall.zig` tool-call parsing and markup stripping.
- `src/jsonschema.zig` documented JSON Schema subset.
- `src/plugin.zig` Manifest v1 validation.
- `src/conformance.zig` wire vector runner.
- `api-snapshot.py` and `api/` public API snapshot.

## Release

Tag shape: `zig/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
