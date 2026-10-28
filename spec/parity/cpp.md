# C++ Parity

- Tier: core
- SPEC_VERSION: 0.2.0

`cpp/v0.1.0` ships the core loop. The Core passes all eleven vector groups, its
core tests, and its public API snapshot. `partial` marks a surface that covers
the vector behavior and common path but not every optional Go hook or provider
adapter.

| Go symbol | C++ symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `Message` | parity | P1 |
| `model.Request` | `Request` | parity | P1 |
| `model.Response` | `Response` | parity | P1 |
| `model.Usage` | `Usage` | parity | P1 |
| `tool.Tool` | `Tool` | parity | P1 |
| `tool.Registry` | `ToolRegistry` | parity | P1 |
| `event.Event` | `Event` | parity | P1 |
| `event.Sink` | `EventSink` | parity | P1 |
| `policy.Decision` | `Decision` | parity | P1 |
| `policy.PathChecker` | `PathChecker` | parity | P1 |
| `memory.Store` | `MemoryStore` | parity | P1 |
| `memory.Record` | `MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `CheckpointAllowlist` | parity | P1 |
| `agent/context.ContextBudget` | `ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `estimate_tokens` | parity | P1 |
| `agent.Agent` | `Agent` | parity | P1 |
| `agent.Options` | `AgentOptions` | parity | P1 |
| `agent.New` | `Agent::Agent` | parity | P1 |
| `agent/stream.StreamPart` | `stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `parse_toolcall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `strip_markup` | parity | P1 |
| `toolcall.ParseInputJSON` | `parse_input_json` | parity | P1 |
| `tool/jsonschema.Schema` | `validate` | partial | P1 |
| `plugin.ParseManifest` | `parse_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `CallLimit` | parity | P1 |
| `agent/middleware.FallbackModel` | `fallback_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `PiiRedactor` | parity | P1 |
| `agent/middleware.StructuredOutput` | `StructuredOutput` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `ToolSelection` | parity | P1 |
