# R Parity

- Tier: core
- SPEC_VERSION: 0.2.0

`r/v0.2.0` ships the core loop. The SDK passes all eleven vector groups and
checks its public API snapshot. `partial` marks a surface that covers the vector
behavior and common path but not every optional Go hook or provider adapter.

| Go symbol | R symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `message` | parity | P1 |
| `model.Request` | `request` | parity | P1 |
| `model.Response` | `response` | parity | P1 |
| `model.Usage` | `usage` | parity | P1 |
| `tool.Tool` | `tool_spec` | partial | P1 |
| `tool.Registry` | `agent_run` | partial | P1 |
| `event.Event` | `event` | parity | P1 |
| `event.Sink` | `sink_emit` | partial | P1 |
| `policy.Decision` | `path_check` | partial | P1 |
| `policy.PathChecker` | `path_checker` | parity | P1 |
| `memory.Store` | `memory_store` | parity | P1 |
| `memory.Record` | `memory_record` | parity | P1 |
| `checkpoint.Allowlist` | `checkpoint_allowlist` | parity | P1 |
| `agent/context.ContextBudget` | `context_budget` | parity | P1 |
| `agent/context.EstimateTokens` | `estimate_tokens` | parity | P1 |
| `agent.Agent` | `agent_run` | parity | P1 |
| `agent.Options` | `agent_run` | partial | P1 |
| `agent.New` | `agent_run` | parity | P1 |
| `agent/stream.StreamPart` | `stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `toolcall_parse` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `toolcall_strip` | parity | P1 |
| `toolcall.ParseInputJSON` | `toolcall_parse_input` | parity | P1 |
| `tool/jsonschema.Schema` | `schema_validate` | partial | P1 |
| `plugin.ParseManifest` | `plugin_parse_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `call_limit` | parity | P1 |
| `agent/middleware.FallbackModel` | `fallback_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `pii_redact` | parity | P1 |
| `agent/middleware.StructuredOutput` | `structured_output` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `tool_selection` | parity | P1 |
