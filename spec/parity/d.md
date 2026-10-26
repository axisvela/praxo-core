# D Parity

- Tier: core
- SPEC_VERSION: 0.2.0

`d/v0.1.0` ships the core loop. The SDK passes all eleven vector groups, its
tests, and its public API snapshot. `partial` marks a surface that covers the
vector behavior and common path but not every optional Go hook or provider
adapter.

| Go symbol | D symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `praxo.models.Message` | parity | P1 |
| `model.Request` | `praxo.models.Request` | parity | P1 |
| `model.Response` | `praxo.models.Response` | parity | P1 |
| `model.Usage` | `praxo.models.Usage` | parity | P1 |
| `tool.Tool` | `praxo.agent.Tool` | parity | P1 |
| `tool.Registry` | `praxo.agent.Registry` | parity | P1 |
| `event.Event` | `praxo.models.Event` | parity | P1 |
| `event.Sink` | `praxo.runtime.EventSink` | partial | P1 |
| `policy.Decision` | `praxo.models.Decision` | parity | P1 |
| `policy.PathChecker` | `praxo.runtime.PathChecker` | parity | P1 |
| `memory.Store` | `praxo.runtime.MemoryStore` | parity | P1 |
| `memory.Record` | `praxo.models.MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `praxo.runtime.CheckpointAllowlist` | parity | P1 |
| `agent/context.ContextBudget` | `praxo.runtime.ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `praxo.runtime.estimateTokens` | parity | P1 |
| `agent.Agent` | `praxo.agent.Agent` | parity | P1 |
| `agent.Options` | `praxo.agent.AgentOptions` | parity | P1 |
| `agent.New` | `praxo.agent.runAgent` | parity | P1 |
| `agent/stream.StreamPart` | `praxo.models.streamKinds` | partial | P1 |
| `toolcall.ParseToolCall` | `praxo.toolcall.parseToolCall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `praxo.toolcall.stripMarkup` | parity | P1 |
| `toolcall.ParseInputJSON` | `praxo.toolcall.parseInputJson` | parity | P1 |
| `tool/jsonschema.Schema` | `praxo.jsonschema.validate` | partial | P1 |
| `plugin.ParseManifest` | `praxo.plugin.parseManifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `praxo.middleware.CallLimit` | parity | P1 |
| `agent/middleware.FallbackModel` | `praxo.middleware.fallbackModel` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `praxo.middleware.PiiRedactor` | parity | P1 |
| `agent/middleware.StructuredOutput` | `praxo.middleware.StructuredOutput` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `praxo.middleware.ToolSelection` | parity | P1 |
