# Lua Parity

- Tier: core
- SPEC_VERSION: 0.2.0

`lua/v0.1.0` ships the core loop. The SDK passes all eleven vector groups, its
core tests, and its public API snapshot. `partial` marks a surface that covers
the vector behavior and common path but not every optional Go hook or provider
adapter.

| Go symbol | Lua symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `models.message` | parity | P1 |
| `model.Request` | `models.request` | parity | P1 |
| `model.Response` | `models.response` | parity | P1 |
| `model.Usage` | `models.usage` | parity | P1 |
| `tool.Tool` | `agent.func_tool` | parity | P1 |
| `tool.Registry` | `agent.tool_registry` | parity | P1 |
| `event.Event` | `models.event` | parity | P1 |
| `event.Sink` | `runtime.multi_sink` | partial | P1 |
| `policy.Decision` | `models.decision` | parity | P1 |
| `policy.PathChecker` | `runtime.path_checker` | parity | P1 |
| `memory.Store` | `runtime.memory_store` | parity | P1 |
| `memory.Record` | `models.memory_record` | parity | P1 |
| `checkpoint.Allowlist` | `runtime.checkpoint_allowlist` | parity | P1 |
| `agent/context.ContextBudget` | `runtime.context_budget` | parity | P1 |
| `agent/context.EstimateTokens` | `runtime.estimate_tokens` | parity | P1 |
| `agent.Agent` | `agent.run_agent` | parity | P1 |
| `agent.Options` | `agent.agent_options` | parity | P1 |
| `agent.New` | `agent.agent_options` | parity | P1 |
| `agent/stream.StreamPart` | `models.STREAM_KINDS` | partial | P1 |
| `toolcall.ParseToolCall` | `toolcall.parse_toolcall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `toolcall.strip_markup` | parity | P1 |
| `toolcall.ParseInputJSON` | `toolcall.parse_input_json` | parity | P1 |
| `tool/jsonschema.Schema` | `jsonschema.validate` | partial | P1 |
| `plugin.ParseManifest` | `plugin.parse_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `middleware.call_limit` | parity | P1 |
| `agent/middleware.FallbackModel` | `middleware.fallback_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `middleware.redact` | parity | P1 |
| `agent/middleware.StructuredOutput` | `middleware.structured_output` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `middleware.tool_selection` | parity | P1 |
