# Erlang Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Released source tag `erlang/v0.1.0` ships a native core loop on Erlang/OTP 29.
The Core passes all eleven vector groups, native tests, and the public API
snapshot. The agent integrates opt-in PII redaction, structured output, call
limits, and tool selection; fallback models are supported. `partial` marks a
surface that covers the vector behavior and common path but not every optional Go
hook or provider adapter. Built-in provider configuration, streaming, and plugin
hosts are not provided. A synchronous function can serve as a consumer-supplied
model and participate in fallback.

| Go symbol | Erlang symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `praxo_models.message/2` | parity | P1 |
| `model.Request` | `praxo_models.request/2` | parity | P1 |
| `model.Response` | `praxo_models.response/2` | parity | P1 |
| `model.Usage` | `praxo_models.usage/2` | parity | P1 |
| `tool.Tool` | `praxo_agent.new_tool/3` | parity | P1 |
| `tool.Registry` | `praxo_agent.new_agent_options/1` | partial | P1 |
| `event.Event` | `praxo_models.event/4` | parity | P1 |
| `event.Sink` | `praxo_sink.new/0` | parity | P1 |
| `policy.Decision` | `praxo_models.decision/2` | parity | P1 |
| `policy.PathChecker` | `praxo_runtime.path_checker/1` | parity | P1 |
| `memory.Store` | `praxo_memory.new/0` | parity | P1 |
| `memory.Record` | `praxo_models.memory_record/4` | parity | P1 |
| `checkpoint.Allowlist` | `praxo_checkpoint.new/0` | parity | P1 |
| `agent/context.ContextBudget` | `praxo_models.context_budget/2` | parity | P1 |
| `agent/context.EstimateTokens` | `praxo_runtime.estimate_tokens/1` | parity | P1 |
| `agent.Agent` | `praxo_agent.run_agent/3` | parity | P1 |
| `agent.Options` | `praxo_agent.new_agent_options/1` | parity | P1 |
| `agent.New` | `praxo_agent.new_agent_options/1` | parity | P1 |
| `agent/stream.StreamPart` | `praxo_models.stream_kinds/0` | partial | P1 |
| `toolcall.ParseToolCall` | `praxo_toolcall.parse_tool_call/1` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `praxo_toolcall.strip_tool_call_markup/1` | parity | P1 |
| `toolcall.ParseInputJSON` | `praxo_toolcall.parse_input_json/1` | parity | P1 |
| `tool/jsonschema.Schema` | `praxo_jsonschema.validate/2` | partial | P1 |
| `plugin.ParseManifest` | `praxo_plugin.parse_manifest/1` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `praxo_middleware.call_limit/2` | parity | P1 |
| `agent/middleware.FallbackModel` | `praxo_agent.fallback_model/2` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `praxo_middleware.pii_redact/1` | parity | P1 |
| `agent/middleware.StructuredOutput` | `praxo_middleware.structured_output/3` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `praxo_middleware.tool_selection/1` | parity | P1 |
