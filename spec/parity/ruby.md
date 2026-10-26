# Ruby Parity

- Tier: core
- SPEC_VERSION: 0.2.0

`ruby/v0.1.0` ships the core loop. The SDK passes all eleven vector groups, its
core tests, and its public API snapshot. `partial` marks a surface that covers
the vector behavior and common path but not every optional Go hook or provider
adapter.

| Go symbol | Ruby symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `Praxo::Models::Message` | parity | P1 |
| `model.Request` | `Praxo::Models::Request` | parity | P1 |
| `model.Response` | `Praxo::Models::Response` | parity | P1 |
| `model.Usage` | `Praxo::Models::Usage` | parity | P1 |
| `tool.Tool` | `Praxo::Agent::FuncTool` | parity | P1 |
| `tool.Registry` | `Praxo::Agent::ToolRegistry` | parity | P1 |
| `event.Event` | `Praxo::Models::Event` | parity | P1 |
| `event.Sink` | `Praxo::Runtime::MultiSink` | partial | P1 |
| `policy.Decision` | `Praxo::Models::Decision` | parity | P1 |
| `policy.PathChecker` | `Praxo::Runtime::PathChecker` | parity | P1 |
| `memory.Store` | `Praxo::Runtime::MemoryStore` | parity | P1 |
| `memory.Record` | `Praxo::Models::MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `Praxo::Runtime::CheckpointAllowlist` | parity | P1 |
| `agent/context.ContextBudget` | `Praxo::Runtime::ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `Praxo::Runtime.estimate_tokens` | parity | P1 |
| `agent.Agent` | `Praxo::Agent::Runner` | parity | P1 |
| `agent.Options` | `Praxo::Agent::AgentOptions` | parity | P1 |
| `agent.New` | `Praxo::Agent::Runner.new` | parity | P1 |
| `agent/stream.StreamPart` | `Praxo::Models::STREAM_KINDS` | partial | P1 |
| `toolcall.ParseToolCall` | `Praxo::Toolcall.parse_toolcall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `Praxo::Toolcall.strip_markup` | parity | P1 |
| `toolcall.ParseInputJSON` | `Praxo::Toolcall.parse_input_json` | parity | P1 |
| `tool/jsonschema.Schema` | `Praxo::JsonSchema.validate` | partial | P1 |
| `plugin.ParseManifest` | `Praxo::Plugin.parse_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `Praxo::Middleware::CallLimit` | parity | P1 |
| `agent/middleware.FallbackModel` | `Praxo::Middleware.fallback_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `Praxo::Middleware::PiiRedactor` | parity | P1 |
| `agent/middleware.StructuredOutput` | `Praxo::Middleware::StructuredOutput` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `Praxo::Middleware::ToolSelection` | parity | P1 |
