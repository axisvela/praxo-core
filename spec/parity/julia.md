# Julia Parity

- Tier: core
- SPEC_VERSION: 0.2.0

`julia/v0.2.0` ships the core loop. The Core passes all eleven vector groups and
checks its public API snapshot. `partial` marks a surface that covers the vector
behavior and common path but not every optional Go hook or provider adapter.

| Go symbol | Julia symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Model` | `AbstractModel` | parity | P1 |
| `model.Message` | `Message` | parity | P1 |
| `model.Request` | `Request` | parity | P1 |
| `model.Response` | `Response` | parity | P1 |
| `model.Usage` | `Usage` | parity | P1 |
| `tool.Tool` | `AbstractTool` | parity | P1 |
| `tool.Registry` | `ToolRegistry` | parity | P1 |
| `event.Event` | `Event` | parity | P1 |
| `event.Sink` | `AbstractSink` | parity | P1 |
| `policy.Hook` | `AbstractPolicy` | parity | P1 |
| `policy.Decision` | `Decision` | parity | P1 |
| `policy.PathChecker` | `PathChecker` | parity | P1 |
| `memory.Store` | `MemoryStore` | parity | P1 |
| `memory.Record` | `MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `CheckpointAllowlist` | parity | P1 |
| `agent/context.ContextBudget` | `ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `estimate_tokens` | parity | P1 |
| `agent.Agent` | `Agent` | parity | P1 |
| `agent.Options` | `AgentOptions` | parity | P1 |
| `agent.New` | `Agent` | parity | P1 |
| `agent/stream.StreamPart` | `StreamKinds` | partial | P1 |
| `toolcall.ParseToolCall` | `ToolCallParser.parse_toolcall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `ToolCallParser.strip_markup` | parity | P1 |
| `toolcall.ParseInputJSON` | `ToolCallParser.parse_input_json` | parity | P1 |
| `tool/jsonschema.Schema` | `JsonSchema.validate` | partial | P1 |
| `plugin.ParseManifest` | `Plugin.parse_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `CallLimitMiddleware` | parity | P1 |
| `agent/middleware.FallbackModel` | `fallback_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `PiiMiddleware` | parity | P1 |
| `agent/middleware.StructuredOutput` | `StructuredOutput` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `ToolSelectionMiddleware` | parity | P1 |
