# OCaml Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Released source tag `ocaml/v0.2.0` ships a native Core implementation. It passes
all eleven vector groups, its tests, and its public API snapshot. The agent
integrates opt-in PII redaction, structured output, call limits, and tool
selection; fallback models are supported. `partial` marks a surface that covers
the vector behavior and common path but not every optional Go hook or provider
adapter. Local validation uses OCaml 4.14.2 bytecode; `ocamlopt` is not required
by the declared gate.

| Go symbol | OCaml symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `Praxo.core_message` | parity | P1 |
| `model.Request` | `Praxo.request` | parity | P1 |
| `model.Response` | `Praxo.response` | parity | P1 |
| `model.Usage` | `Praxo.usage` | parity | P1 |
| `tool.Tool` | `Praxo.tool` | parity | P1 |
| `tool.Registry` | `Praxo.agent_options` | partial | P1 |
| `event.Event` | `Praxo.core_event` | parity | P1 |
| `event.Sink` | `Praxo.sink` | parity | P1 |
| `policy.Decision` | `Praxo.decision` | parity | P1 |
| `policy.PathChecker` | `Praxo.path_checker` | parity | P1 |
| `memory.Store` | `Praxo.memory_store` | parity | P1 |
| `memory.Record` | `Praxo.memory_record` | parity | P1 |
| `checkpoint.Allowlist` | `Praxo.checkpoint_allowlist` | parity | P1 |
| `agent/context.ContextBudget` | `Praxo.context_budget` | parity | P1 |
| `agent/context.EstimateTokens` | `Praxo.estimate_tokens` | parity | P1 |
| `agent.Agent` | `Praxo.run_agent` | parity | P1 |
| `agent.Options` | `Praxo.agent_options` | parity | P1 |
| `agent.New` | `Praxo.agent_options` | parity | P1 |
| `agent/stream.StreamPart` | `Praxo.stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `Praxo.parse_tool_call` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `Praxo.strip_tool_call_markup` | parity | P1 |
| `toolcall.ParseInputJSON` | `Praxo.parse_input_json` | parity | P1 |
| `tool/jsonschema.Schema` | `Praxo.validate_schema` | partial | P1 |
| `plugin.ParseManifest` | `Praxo.validate_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `Praxo.call_limit` | parity | P1 |
| `agent/middleware.FallbackModel` | `Praxo.fallback_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `Praxo.pii_redact` | parity | P1 |
| `agent/middleware.StructuredOutput` | `Praxo.structured_output` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `Praxo.tool_selection` | parity | P1 |
