# Elixir Parity

- Tier: core
- SPEC_VERSION: 0.2.0

`elixir/0.1.0` ships the core loop. The SDK passes all eleven vector groups, its
tests, and its public API snapshot. `partial` marks a surface that covers the
vector behavior and common path but not every optional Go hook or provider
adapter. Erlang shares the BEAM runtime and is documented as a runtime, not a
second agent loop.

| Go symbol | Elixir symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `Praxo.Message` | parity | P1 |
| `model.Request` | `Praxo.Request` | parity | P1 |
| `model.Response` | `Praxo.Response` | parity | P1 |
| `model.Usage` | `Praxo.Usage` | parity | P1 |
| `tool.Tool` | `Praxo.Tool` | parity | P1 |
| `tool.Registry` | `Praxo.AgentOptions` | partial | P1 |
| `event.Event` | `Praxo.Event` | parity | P1 |
| `event.Sink` | `Praxo.Sink` | parity | P1 |
| `policy.Decision` | `Praxo.Decision` | parity | P1 |
| `policy.PathChecker` | `Praxo.PathChecker` | parity | P1 |
| `memory.Store` | `Praxo.MemoryStore` | parity | P1 |
| `memory.Record` | `Praxo.MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `Praxo.CheckpointAllowlist` | parity | P1 |
| `agent/context.ContextBudget` | `Praxo.ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `Praxo.Runtime.estimate_tokens` | parity | P1 |
| `agent.Agent` | `Praxo.Agent.run_agent` | parity | P1 |
| `agent.Options` | `Praxo.AgentOptions` | parity | P1 |
| `agent.New` | `Praxo.Agent.new_agent_options` | parity | P1 |
| `agent/stream.StreamPart` | `Praxo.Models.stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `Praxo.ToolCallParser.parse_tool_call` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `Praxo.ToolCallParser.strip_tool_call_markup` | parity | P1 |
| `toolcall.ParseInputJSON` | `Praxo.ToolCallParser.parse_input_json` | parity | P1 |
| `tool/jsonschema.Schema` | `Praxo.JsonSchema.validate` | partial | P1 |
| `plugin.ParseManifest` | `Praxo.Plugin.parse_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `Praxo.Middleware.call_limit` | parity | P1 |
| `agent/middleware.FallbackModel` | `Praxo.Agent.fallback_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `Praxo.Middleware.pii_redact` | parity | P1 |
| `agent/middleware.StructuredOutput` | `Praxo.StructuredOutput` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `Praxo.Middleware.tool_selection` | parity | P1 |
