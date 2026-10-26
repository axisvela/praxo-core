# Zig Parity

- Tier: wire
- SPEC_VERSION: 0.2.0

`zig/v0.1.0` ships the wire subset: toolcall, JSON Schema, and plugin
manifests. The core loop, middleware, and adapters are follow-up work.

| Go symbol | Zig symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `parseToolCall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `stripMarkup` | parity | P1 |
| `toolcall.ParseInputJSON` | `parseInputJson` | parity | P1 |
| `tool/jsonschema.Schema` | `validate` | partial | P1 |
| `plugin.ParseManifest` | `parseManifest` | parity | P1 |
