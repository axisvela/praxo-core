# Julia Parity

- Tier: wire
- SPEC_VERSION: 0.2.0

`julia/v0.1.0` ships the wire subset: toolcall, JSON Schema, and plugin
manifests. The core loop, middleware, and adapters are follow-up work.

| Go symbol | Julia symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `ToolCallParser.parse_toolcall` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `ToolCallParser.strip_markup` | partial | P1 |
| `toolcall.ParseInputJSON` | `ToolCallParser.parse_input_json` | partial | P1 |
| `tool/jsonschema.Schema` | `JsonSchema.validate` | partial | P1 |
| `plugin.ParseManifest` | `Plugin.parse_manifest` | partial | P1 |
