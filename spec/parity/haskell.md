# Haskell Parity

- Tier: wire
- SPEC_VERSION: 0.2.0

Unreleased Wire candidate. Local checks cover the `toolcall`, `jsonschema`,
`plugin`, and `agent-loop` vectors, native regression tests, and the source API
snapshot. Previous Linux and Windows CI covered the three wire groups; the new
loop has not been verified in remote CI. This does not establish Core parity or
provide a provider adapter.

| Go symbol | Haskell symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ToolCall` | `Praxo.ToolCall.ToolCall` | partial | P1 |
| `toolcall.ParseToolCall` | `Praxo.ToolCall.parseToolCall` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `Praxo.ToolCall.stripToolCallMarkup` | partial | P1 |
| `tool/jsonschema.Schema` | `Praxo.JsonSchema.validateSchema` | partial | P1 |
| `tool/jsonschema.ValidationError` | `Praxo.JsonSchema.ValidationError` | partial | P1 |
| `plugin.ParseManifest` | `Praxo.Plugin.parseManifest` | partial | P1 |
| `agent.Agent` | `Praxo.Agent.runAgent` | partial | P1 |
| `agent.Options` | `Praxo.Agent.AgentOptions` | partial | P1 |
| `agent.RunResult` | `Praxo.Agent.RunResult` | partial | P1 |

JSON and bounded pattern helpers are SDK-local utilities, not new normative
contract symbols. See `language/haskell/README.md` for syntax and resource limits.
