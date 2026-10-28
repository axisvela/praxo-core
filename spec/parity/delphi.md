# Delphi / Free Pascal Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Released source tag `delphi/v0.2.1` ships a native Core implementation verified
with Free Pascal 3.2.2 on Windows i386. It passes all eleven vector groups, native
tests, and the public API snapshot. The commercial Delphi compiler and other
targets are not independently verified. `partial` marks a surface that covers the
vector behavior and common path but not every optional Go hook or provider
adapter. Runtime and middleware helpers are provided; the callback-based agent
loop is synchronous and does not automatically apply every opt-in helper.

| Go symbol | Delphi/Free Pascal symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `PraxoMessageWire` | parity | P1 |
| `model.Request` | `PraxoRunAgent` | partial | P1 |
| `model.Response` | `PraxoRunAgent` | partial | P1 |
| `model.Usage` | `PraxoRunAgent` | partial | P1 |
| `tool.Tool` | `PraxoRunAgent` | partial | P1 |
| `tool.Registry` | `PraxoSelectTools` | partial | P1 |
| `event.Event` | `PraxoEventEmit` | parity | P1 |
| `event.Sink` | `PraxoEventNew` | parity | P1 |
| `policy.Decision` | `PraxoPathCheck` | parity | P1 |
| `policy.PathChecker` | `PraxoPathChecker` | parity | P1 |
| `memory.Store` | `PraxoMemoryNew` | parity | P1 |
| `memory.Record` | `PraxoMemoryPut` | parity | P1 |
| `checkpoint.Allowlist` | `PraxoCheckpointNew` | parity | P1 |
| `agent/context.ContextBudget` | `PraxoCompactContext` | parity | P1 |
| `agent/context.EstimateTokens` | `PraxoEstimateTokens` | parity | P1 |
| `agent.Agent` | `PraxoRunAgent` | parity | P1 |
| `agent.Options` | `PraxoRunAgent` | partial | P1 |
| `agent.New` | `PraxoRunAgent` | partial | P1 |
| `agent/stream.StreamPart` | `PraxoStreamKinds` | partial | P1 |
| `toolcall.ParseToolCall` | `PraxoParseToolCall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `PraxoStripToolCallMarkup` | parity | P1 |
| `toolcall.ParseInputJSON` | `PraxoParseJSON` | partial | P1 |
| `tool/jsonschema.Schema` | `PraxoValidateSchema` | partial | P1 |
| `plugin.ParseManifest` | `PraxoValidateManifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `PraxoCallLimit` | parity | P1 |
| `agent/middleware.FallbackModel` | `PraxoFallback` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `PraxoPiiRedact` | parity | P1 |
| `agent/middleware.StructuredOutput` | `PraxoStructuredOutput` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `PraxoSelectTools` | parity | P1 |
