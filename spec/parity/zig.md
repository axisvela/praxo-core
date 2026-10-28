# Zig Parity

- Tier: core
- SPEC_VERSION: 0.2.0

`zig/v0.2.0` ships the core loop. The Core passes all eleven vector groups, its
tests, and its public API snapshot. `zig/v0.1.0` remains the wire tag.
`partial` marks a surface that covers the vector behavior and common path but
not every optional Go hook or provider adapter.

| Go symbol | Zig symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `models.Message` | parity | P1 |
| `model.Request` | `models.Request` | parity | P1 |
| `model.Response` | `models.Response` | parity | P1 |
| `model.Usage` | `models.Usage` | parity | P1 |
| `tool.Tool` | `agent.Tool` | parity | P1 |
| `tool.Registry` | `agent.Registry` | parity | P1 |
| `event.Event` | `models.Event` | parity | P1 |
| `event.Sink` | `runtime.EventSink` | partial | P1 |
| `policy.Decision` | `models.Decision` | parity | P1 |
| `policy.PathChecker` | `runtime.PathChecker` | parity | P1 |
| `memory.Store` | `runtime.MemoryStore` | parity | P1 |
| `memory.Record` | `models.MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `runtime.CheckpointAllowlist` | parity | P1 |
| `agent/context.ContextBudget` | `runtime.ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `runtime.estimateTokens` | parity | P1 |
| `agent.Agent` | `agent.Agent` | parity | P1 |
| `agent.Options` | `agent.AgentOptions` | parity | P1 |
| `agent.New` | `agent.Agent.init` | parity | P1 |
| `agent/stream.StreamPart` | `models.stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `parseToolCall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `stripMarkup` | parity | P1 |
| `toolcall.ParseInputJSON` | `parseInputJson` | parity | P1 |
| `tool/jsonschema.Schema` | `validate` | partial | P1 |
| `plugin.ParseManifest` | `parseManifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `middleware.CallLimit` | parity | P1 |
| `agent/middleware.FallbackModel` | `middleware.Fallback` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `middleware.PiiRedactor` | parity | P1 |
| `agent/middleware.StructuredOutput` | `middleware.StructuredOutput` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `middleware.ToolSelection` | parity | P1 |
