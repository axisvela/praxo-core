# Nim Parity

- Tier: core
- SPEC_VERSION: 0.2.0

The unreleased Nim candidate includes a core loop. It passes all eleven vector groups, its
tests, and its public API snapshot. These results do not establish full Core
parity or production readiness. PII, structured output, and call limit remain
standalone helpers; opt-in tool selection is enforced by the agent.
`callbackModel` accepts a synchronous consumer closure from `Request` to
`Response`; catchable errors propagate and can trigger `fallbackModel`. Built-in
provider integrations, streaming wire encodings, and plugin hosts are not
provided. `partial` marks these and other incomplete surfaces.

| Go symbol | Nim symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `Message` | parity | P1 |
| `model.Request` | `Request` | parity | P1 |
| `model.Response` | `Response` | parity | P1 |
| `model.Usage` | `Usage` | parity | P1 |
| `tool.Tool` | `Tool` | parity | P1 |
| `tool.Registry` | `AgentOptions` | partial | P1 |
| `event.Event` | `Event` | parity | P1 |
| `event.Sink` | `Sink` | parity | P1 |
| `policy.Decision` | `Decision` | parity | P1 |
| `policy.PathChecker` | `PathChecker` | parity | P1 |
| `memory.Store` | `MemoryStore` | parity | P1 |
| `memory.Record` | `MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `CheckpointAllowlist` | parity | P1 |
| `agent/context.ContextBudget` | `ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `estimateTokens` | parity | P1 |
| `agent.Agent` | `runAgent` | parity | P1 |
| `agent.Options` | `AgentOptions` | parity | P1 |
| `agent.New` | `newAgentOptions` | parity | P1 |
| `agent/stream.StreamPart` | `streamKinds` | partial | P1 |
| `toolcall.ParseToolCall` | `parseToolCall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `stripToolCallMarkup` | parity | P1 |
| `toolcall.ParseInputJSON` | `parseInputJson` | parity | P1 |
| `tool/jsonschema.Schema` | `validateSchema` | partial | P1 |
| `plugin.ParseManifest` | `parseManifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `callLimit` | partial | P1 |
| `agent/middleware.FallbackModel` | `fallbackModel` | partial | P1 |
| `agent/middleware.PIIMiddleware` | `piiRedact` | partial | P1 |
| `agent/middleware.StructuredOutput` | `StructuredOutput` | partial | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `toolSelection` | partial | P1 |
