# Haskell Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Released source tag `haskell/v0.2.0` ships a native Core implementation. It
passes all eleven vector groups, native regression tests, and the source API
snapshot. `partial` marks a surface that covers the vector behavior and common
path but not every optional Go hook or provider adapter. The agent loop supports
step/token budgets and events; runtime helpers cover memory, events, checkpoints,
policy, context, and middleware.

| Go symbol | Haskell symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `Praxo.Agent.Message` | parity | P1 |
| `model.Request` | `Praxo.Agent.AgentOptions` | partial | P1 |
| `model.Response` | `Praxo.Agent.Response` | parity | P1 |
| `model.Usage` | `Praxo.Agent.Response` | partial | P1 |
| `tool.Tool` | `Praxo.Agent.AgentOptions` | partial | P1 |
| `tool.Registry` | `Praxo.Agent.AgentOptions` | partial | P1 |
| `event.Event` | `Praxo.Runtime.Event` | parity | P1 |
| `event.Sink` | `Praxo.Runtime.Sink` | parity | P1 |
| `policy.Decision` | `Praxo.Runtime.Decision` | parity | P1 |
| `policy.PathChecker` | `Praxo.Runtime.PathChecker` | parity | P1 |
| `memory.Store` | `Praxo.Runtime.MemoryStore` | parity | P1 |
| `memory.Record` | `Praxo.Runtime.MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `Praxo.Runtime.checkpointMarshal` | parity | P1 |
| `agent/context.ContextBudget` | `Praxo.Runtime.ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `Praxo.Runtime.estimateTokens` | parity | P1 |
| `agent.Agent` | `Praxo.Agent.runAgent` | parity | P1 |
| `agent.Options` | `Praxo.Agent.AgentOptions` | parity | P1 |
| `agent.New` | `Praxo.Agent.AgentOptions` | parity | P1 |
| `agent/stream.StreamPart` | `Praxo.Runtime.streamKinds` | partial | P1 |
| `toolcall.ToolCall` | `Praxo.ToolCall.ToolCall` | parity | P1 |
| `toolcall.ParseToolCall` | `Praxo.ToolCall.parseToolCall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `Praxo.ToolCall.stripToolCallMarkup` | parity | P1 |
| `toolcall.ParseInputJSON` | `Praxo.ToolCall.parseInputJson` | parity | P1 |
| `tool/jsonschema.Schema` | `Praxo.JsonSchema.validateSchema` | partial | P1 |
| `tool/jsonschema.ValidationError` | `Praxo.JsonSchema.ValidationError` | parity | P1 |
| `plugin.ParseManifest` | `Praxo.Plugin.parseManifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `Praxo.Middleware.callLimit` | parity | P1 |
| `agent/middleware.FallbackModel` | `Praxo.Middleware.fallbackEither` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `Praxo.Middleware.piiRedact` | parity | P1 |
| `agent/middleware.StructuredOutput` | `Praxo.Middleware.structuredOutput` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `Praxo.Middleware.toolSelection` | parity | P1 |
