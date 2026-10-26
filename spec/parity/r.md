# R Parity

- Tier: wire
- SPEC_VERSION: 0.2.0

`r/v0.1.0` ships the wire subset: toolcall, JSON Schema, and plugin manifests.
The core loop, middleware, and adapters are follow-up work.

| Go symbol | R symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `toolcall_parse` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `toolcall_strip` | partial | P1 |
| `toolcall.ParseInputJSON` | `toolcall_parse_input` | partial | P1 |
| `tool/jsonschema.Schema` | `schema_validate` | partial | P1 |
| `plugin.ParseManifest` | `plugin_parse_manifest` | partial | P1 |
