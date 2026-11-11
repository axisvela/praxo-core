# OCaml Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Released source tag `ocaml/v0.4.0` ships a native Core implementation. It passes
all eleven vector groups, its tests, and its public API snapshot. The agent
integrates opt-in PII redaction, structured output, call limits, and tool
selection; fallback models are supported. `partial` marks a surface that covers
the vector behavior and common path but not every optional Go hook or provider
adapter. Local validation uses OCaml 4.14.2 bytecode; `ocamlopt` is not required
by the declared gate.

| Go symbol | OCaml symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `Praxo_core.core_message` | parity | P1 |
| `model.Request` | `Praxo_core.request` | parity | P1 |
| `model.Response` | `Praxo_core.response` | parity | P1 |
| `model.Usage` | `Praxo_core.usage` | parity | P1 |
| `tool.Tool` | `Praxo_core.tool` | parity | P1 |
| `tool.Registry` | `Praxo_core.agent_options` | partial | P1 |
| `event.Event` | `Praxo_core.core_event` | parity | P1 |
| `event.Sink` | `Praxo_core.sink` | parity | P1 |
| `policy.Decision` | `Praxo_core.decision` | parity | P1 |
| `policy.PathChecker` | `Praxo_core.path_checker` | parity | P1 |
| `memory.Store` | `Praxo_core.memory_store` | parity | P1 |
| `memory.Record` | `Praxo_core.memory_record` | parity | P1 |
| `checkpoint.Allowlist` | `Praxo_core.checkpoint_allowlist` | parity | P1 |
| `agent/context.ContextBudget` | `Praxo_core.context_budget` | parity | P1 |
| `agent/context.EstimateTokens` | `Praxo_core.estimate_tokens` | parity | P1 |
| `agent.Agent` | `Praxo_core.run_agent` | parity | P1 |
| `agent.Options` | `Praxo_core.agent_options` | parity | P1 |
| `agent.New` | `Praxo_core.agent_options` | parity | P1 |
| `agent/stream.StreamPart` | `Praxo_core.stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `Praxo_core.parse_tool_call` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `Praxo_core.strip_tool_call_markup` | parity | P1 |
| `toolcall.ParseInputJSON` | `Praxo_core.parse_input_json` | parity | P1 |
| `tool/jsonschema.Schema` | `Praxo_core.validate_schema` | partial | P1 |
| `plugin.ParseManifest` | `Praxo_core.validate_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `Praxo_core.call_limit` | parity | P1 |
| `agent/middleware.FallbackModel` | `Praxo_core.fallback_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `Praxo_core.pii_redact` | parity | P1 |
| `agent/middleware.StructuredOutput` | `Praxo_core.structured_output` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `Praxo_core.tool_selection` | parity | P1 |
