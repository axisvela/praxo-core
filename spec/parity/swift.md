# Swift Parity

- Tier: core
- SPEC_VERSION: 0.2.0

`swift/v0.2.0` ships the core loop. The Core passes all eleven vector groups and
checks its public API snapshot. `partial` marks a surface that covers the vector
behavior and common path but not every optional Go hook or provider adapter.

| Go symbol | Swift symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Model` | `Model` | parity | P1 |
| `model.Message` | `Message` | parity | P1 |
| `model.Request` | `Request` | parity | P1 |
| `model.Response` | `Response` | parity | P1 |
| `model.Usage` | `Usage` | parity | P1 |
| `tool.Tool` | `Tool` | parity | P1 |
| `tool.Registry` | `ToolRegistry` | parity | P1 |
| `event.Event` | `Event` | parity | P1 |
| `event.Sink` | `EventSink` | parity | P1 |
| `policy.Hook` | `PolicyHook` | parity | P1 |
| `policy.Decision` | `Decision` | parity | P1 |
| `policy.PathChecker` | `PathChecker` | parity | P1 |
| `memory.Store` | `MemoryStore` | parity | P1 |
| `memory.Record` | `MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `CheckpointAllowlist` | parity | P1 |
| `agent/context.ContextBudget` | `ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `ContextEstimator` | parity | P1 |
| `agent.Agent` | `Agent` | parity | P1 |
| `agent.Options` | `AgentOptions` | parity | P1 |
| `agent.New` | `Agent.init` | parity | P1 |
| `agent/stream.StreamPart` | `streamKinds` | partial | P1 |
| `toolcall.ParseToolCall` | `ToolCallParser.parse` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `ToolCallParser.stripMarkup` | parity | P1 |
| `toolcall.ParseInputJSON` | `ToolCallParser.parseInputJson` | parity | P1 |
| `tool/jsonschema.Schema` | `JsonSchema.validate` | partial | P1 |
| `plugin.ParseManifest` | `Plugin.parseManifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `CallLimit` | parity | P1 |
| `agent/middleware.FallbackModel` | `Fallback.wrap` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `PiiRedactor` | parity | P1 |
| `agent/middleware.StructuredOutput` | `StructuredOutput` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `ToolSelection` | parity | P1 |
