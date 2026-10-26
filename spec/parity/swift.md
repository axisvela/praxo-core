# Swift Parity

- Tier: wire
- SPEC_VERSION: 0.2.0

`swift/v0.1.0` ships the wire subset: toolcall, JSON Schema, and plugin
manifests. The core loop, middleware, and adapters are follow-up work.

| Go symbol | Swift symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `ToolCallParser.parse` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `ToolCallParser.stripMarkup` | partial | P1 |
| `toolcall.ParseInputJSON` | `ToolCallParser.parseInputJson` | partial | P1 |
| `tool/jsonschema.Schema` | `JsonSchema.validate` | partial | P1 |
| `plugin.ParseManifest` | `Plugin.parseManifest` | partial | P1 |
