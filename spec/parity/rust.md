# Rust Parity

- Tier: core
- SPEC_VERSION: 0.2.0

| Go symbol | Rust symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Model` | `model::Model` | parity | P1 |
| `model.Message` | `model::Message` | parity | P1 |
| `model.Request` | `model::Request` | parity | P1 |
| `model.Response` | `model::Response` | parity | P1 |
| `model.Usage` | `model::Usage` | parity | P1 |
| `tool.Tool` | `tool::Tool` | parity | P1 |
| `tool.Registry` | `tool::Registry` | parity | P1 |
| `tool.Gateway` | `tool::Gateway` | planned | P2 |
| `event.Event` | `event::Event` | parity | P1 |
| `event.Sink` | `event::Sink` | parity | P1 |
| `policy.Hook` | `policy::Hook` | parity | P1 |
| `policy.Decision` | `policy::Decision` | parity | P1 |
| `policy.PathChecker` | `policy::PathChecker` | parity | P1 |
| `memory.Store` | `memory::Store` | parity | P1 |
| `memory.Record` | `memory::MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `checkpoint::Allowlist` | parity | P1 |
| `agent/context.ContextBudget` | `context::ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `context::estimate_tokens` | parity | P1 |
| `agent/context.LoadAgentsMD` | `context::load_agents_md` | parity | P1 |
| `agent/context.ModelSummarizer` | `context::ModelSummarizer` | parity | P1 |
| `agent/context.Offloader` | `context::Offloader` | parity | P1 |
| `agent.Agent` | `agent::Agent` | parity | P1 |
| `agent.Options` | `agent::AgentOptions` | parity | P1 |
| `agent.New` | `agent::Agent::new` | parity | P1 |
| `agent/stream.StreamPart` | `stream::StreamPart` | parity | P1 |
| `toolcall.ParseToolCall` | `toolcall::parse` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `toolcall::strip_markup` | parity | P1 |
| `toolcall.ParseInputJSON` | `toolcall::parse_input_json` | parity | P1 |
| `tool/jsonschema.Schema` | `jsonschema::validate` | partial | P1 |
| `plugin.ParseManifest` | `plugin::parse_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `middleware::CallLimitMiddleware` | parity | P1 |
| `agent/middleware.FallbackModel` | `middleware::fallback_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `middleware::PiiMiddleware` | parity | P1 |
| `agent/middleware.StructuredOutput` | `middleware::StructuredOutput` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `middleware::ToolSelectionMiddleware` | parity | P1 |
