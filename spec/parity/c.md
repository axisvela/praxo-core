# C Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Released source tag `c/v0.2.0`. The C11 SDK exercises all eleven vector groups through a
public Core API for memory, events, checkpoints, policy, context, middleware, and
the agent loop. JSON remains the wire-level primitive; `partial` marks a surface
that is narrower than the corresponding Go type or provider integration.

The vector adapters call the public Core APIs; scripted models and echo tools
provide fixture setup only. The context API represents role/content text only,
so adapters reject rich messages rather than dropping their fields. The agent
options do not expose a tool registry or advertised tool list. Policy checks
are lexical and do not establish filesystem or symlink containment. The agent
loop has no cancellation token or callback-abort path, so it is bounded only by
step, token, and callback-error limits. `PxCallLimit` is per-run mutable state
without synchronization and must not be shared by concurrent runs. Fixture
coverage does not imply parity for these unrepresented capabilities.

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
| `policy.PathChecker` | `px_path_checker` | partial | P1 |
| `memory.Store` | `px_memory_init` | parity | P1 |
| `memory.Record` | `px_memory_put` | parity | P1 |
| `checkpoint.Allowlist` | `px_checkpoint_init` | parity | P1 |
| `agent/context.ContextBudget` | `px_compact_context` | partial | P1 |
| `agent/context.EstimateTokens` | `px_estimate_tokens` | partial | P1 |
| `agent.Agent` | `px_agent_run` | partial | P1 |
| `agent.Options` | `px_agent_run` | partial | P1 |
| `agent.New` | `px_agent_run` | partial | P1 |
| `agent/stream.StreamPart` | `px_stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `px_parse_toolcall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `px_strip_toolcall` | parity | P1 |
| `toolcall.ParseInputJSON` | `px_extract_json` | partial | P1 |
| `tool/jsonschema.Schema` | `px_schema_validate` | partial | P1 |
| `plugin.ParseManifest` | `px_plugin_validate` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `px_call_limit_model` | partial | P1 |
| `agent/middleware.FallbackModel` | `px_fallback` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `px_pii_redact` | parity | P1 |
| `agent/middleware.StructuredOutput` | `px_apply_structured` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `px_select_tools` | parity | P1 |
