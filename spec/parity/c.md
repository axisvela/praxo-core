# C Parity

- Tier: core
- SPEC_VERSION: 0.2.0

The C core passes all eleven vectors. The public C API is wire-level; idiomatic
model/agent structs are follow-up work.

| Go symbol | C symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `px_parse_toolcall` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `px_strip_toolcall` | partial | P1 |
| `toolcall.ParseInputJSON` | `px_parse_input_json` | partial | P1 |
| `tool/jsonschema.Schema` | `px_schema_validate` | partial | P1 |
| `plugin.ParseManifest` | `px_plugin_validate` | partial | P1 |
