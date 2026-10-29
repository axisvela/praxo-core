# MATLAB/Octave Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Released source tag `matlab/v0.2.1` ships a native Core implementation. It passes
all eleven vector groups and the public API snapshot under GNU Octave 11.3.0;
MATLAB itself is not independently verified. `partial` marks a surface that
covers the vector behavior and common path but not every optional Go hook or
provider adapter. The agent integrates opt-in PII redaction, structured output,
call limits, and tool selection; fallback models are supported.

| Go symbol | MATLAB/Octave symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `praxo.message` | parity | P1 |
| `model.Request` | `praxo.request` | parity | P1 |
| `model.Response` | `praxo.response` | parity | P1 |
| `model.Usage` | `praxo.usage` | parity | P1 |
| `tool.Tool` | `praxo.tool` | parity | P1 |
| `tool.Registry` | `praxo.agent_options` | partial | P1 |
| `event.Event` | `praxo.event` | parity | P1 |
| `event.Sink` | `praxo.event_new` | parity | P1 |
| `policy.Decision` | `praxo.decision` | parity | P1 |
| `policy.PathChecker` | `praxo.path_checker` | parity | P1 |
| `memory.Store` | `praxo.memory_store` | parity | P1 |
| `memory.Record` | `praxo.memory_record` | parity | P1 |
| `checkpoint.Allowlist` | `praxo.checkpoint_new` | parity | P1 |
| `agent/context.ContextBudget` | `praxo.context_budget` | parity | P1 |
| `agent/context.EstimateTokens` | `praxo.estimate_tokens` | parity | P1 |
| `agent.Agent` | `praxo.agent_run` | parity | P1 |
| `agent.Options` | `praxo.agent_options` | parity | P1 |
| `agent.New` | `praxo.agent_options` | parity | P1 |
| `agent/stream.StreamPart` | `praxo.stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `praxo.parse_tool_call` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `praxo.strip_tool_call_markup` | parity | P1 |
| `toolcall.ParseInputJSON` | `praxo.parse_input_json` | parity | P1 |
| `tool/jsonschema.Schema` | `praxo.validate_schema` | partial | P1 |
| `plugin.ParseManifest` | `praxo.validate_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `praxo.call_limit` | parity | P1 |
| `agent/middleware.FallbackModel` | `praxo.fallback_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `praxo.pii_redact` | parity | P1 |
| `agent/middleware.StructuredOutput` | `praxo.structured_output` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `praxo.tool_selection` | parity | P1 |
