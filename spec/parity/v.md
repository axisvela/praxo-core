# V Parity

- Tier: core
- SPEC_VERSION: 0.2.0

The unreleased V candidate includes a core loop. It passes all eleven vector groups, its
tests, and its public API snapshot. These results do not establish full Core
parity or production readiness. PII, structured output, call limit, and tool
selection are standalone helpers, not integrated agent middleware.
`praxo.callback_model` accepts a synchronous consumer function from `Request` to
`!Response`; errors propagate and can trigger `praxo.fallback_model`. Built-in
provider integrations, streaming wire encodings, and plugin hosts are not
provided. `partial` marks these and other incomplete surfaces.

| Go symbol | V symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `praxo.Message` | parity | P1 |
| `model.Request` | `praxo.Request` | parity | P1 |
| `model.Response` | `praxo.Response` | parity | P1 |
| `model.Usage` | `praxo.Usage` | parity | P1 |
| `tool.Tool` | `praxo.Tool` | parity | P1 |
| `tool.Registry` | `praxo.AgentOptions` | partial | P1 |
| `event.Event` | `praxo.Event` | parity | P1 |
| `event.Sink` | `praxo.Sink` | parity | P1 |
| `policy.Decision` | `praxo.Decision` | parity | P1 |
| `policy.PathChecker` | `praxo.PathChecker` | parity | P1 |
| `memory.Store` | `praxo.MemoryStore` | parity | P1 |
| `memory.Record` | `praxo.MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `praxo.CheckpointAllowlist` | parity | P1 |
| `agent/context.ContextBudget` | `praxo.ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `praxo.estimate_tokens` | parity | P1 |
| `agent.Agent` | `praxo.run_agent` | parity | P1 |
| `agent.Options` | `praxo.AgentOptions` | parity | P1 |
| `agent.New` | `praxo.agent_options` | parity | P1 |
| `agent/stream.StreamPart` | `praxo.stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `praxo.parse_tool_call` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `praxo.strip_tool_call_markup` | parity | P1 |
| `toolcall.ParseInputJSON` | `praxo.parse_input_json` | parity | P1 |
| `tool/jsonschema.Schema` | `praxo.validate_schema` | partial | P1 |
| `plugin.ParseManifest` | `praxo.parse_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `praxo.call_limit` | partial | P1 |
| `agent/middleware.FallbackModel` | `praxo.fallback_model` | partial | P1 |
| `agent/middleware.PIIMiddleware` | `praxo.pii_redact` | partial | P1 |
| `agent/middleware.StructuredOutput` | `praxo.StructuredOutput` | partial | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `praxo.tool_selection` | partial | P1 |
