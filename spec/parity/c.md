# C Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Released source tag `c/v0.2.0`. The C11 SDK passes all eleven vectors and adds a
public Core API for memory, events, checkpoints, policy, context, middleware, and
the agent loop. JSON remains the wire-level primitive; `partial` marks a surface
that is narrower than the corresponding Go type or provider integration.

| Go symbol | C symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `px_message_wire` | partial | P1 |
| `model.Request` | `px_agent_run` | partial | P1 |
| `model.Response` | `px_agent_run` | partial | P1 |
| `model.Usage` | `px_agent_run` | partial | P1 |
| `tool.Tool` | `px_agent_run` | partial | P1 |
| `tool.Registry` | `px_select_tools` | partial | P1 |
| `event.Event` | `px_sink_emit` | parity | P1 |
| `event.Sink` | `px_sink_new` | parity | P1 |
| `policy.Decision` | `px_path_check` | parity | P1 |
| `policy.PathChecker` | `px_path_checker` | parity | P1 |
| `memory.Store` | `px_memory_init` | parity | P1 |
| `memory.Record` | `px_memory_put` | parity | P1 |
| `checkpoint.Allowlist` | `px_checkpoint_init` | parity | P1 |
| `agent/context.ContextBudget` | `px_compact_context` | parity | P1 |
| `agent/context.EstimateTokens` | `px_estimate_tokens` | parity | P1 |
| `agent.Agent` | `px_agent_run` | parity | P1 |
| `agent.Options` | `px_agent_run` | partial | P1 |
| `agent.New` | `px_agent_run` | partial | P1 |
| `agent/stream.StreamPart` | `px_stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `px_parse_toolcall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `px_strip_toolcall` | parity | P1 |
| `toolcall.ParseInputJSON` | `px_extract_json` | partial | P1 |
| `tool/jsonschema.Schema` | `px_schema_validate` | partial | P1 |
| `plugin.ParseManifest` | `px_plugin_validate` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `px_call_limit_model` | parity | P1 |
| `agent/middleware.FallbackModel` | `px_fallback` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `px_pii_redact` | parity | P1 |
| `agent/middleware.StructuredOutput` | `px_apply_structured` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `px_select_tools` | parity | P1 |
