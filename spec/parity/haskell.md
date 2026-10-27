# Haskell Parity

- Tier: wire
- SPEC_VERSION: 0.2.0

Unreleased Wire candidate. Local checks cover 24 vectors in the three groups
`toolcall`, `jsonschema`, and `plugin`, native regression tests, and the source
API snapshot. Linux and Windows CI passed on commit `4273f47`; release review
remains pending. This is not Core
parity and does not provide an agent loop or provider adapter.

| Go symbol | Haskell symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ToolCall` | `Praxo.ToolCall.ToolCall` | partial | P1 |
| `toolcall.ParseToolCall` | `Praxo.ToolCall.parseToolCall` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `Praxo.ToolCall.stripToolCallMarkup` | partial | P1 |
| `tool/jsonschema.Schema` | `Praxo.JsonSchema.validateSchema` | partial | P1 |
| `tool/jsonschema.ValidationError` | `Praxo.JsonSchema.ValidationError` | partial | P1 |
| `plugin.ParseManifest` | `Praxo.Plugin.parseManifest` | partial | P1 |

JSON and bounded pattern helpers are SDK-local utilities, not new normative
contract symbols. See `sdk/haskell/README.md` for syntax and resource limits.
