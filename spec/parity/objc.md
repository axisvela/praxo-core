# Objective-C Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Released source tag `objc/v0.1.0`. Local validation uses clang 21.1.8 with
GNUstep Base 1.31.1 on Windows and the macOS CI job runs the same suite. Both
cover all eleven vector groups, native tests, and the public declaration
snapshot. The agent integrates opt-in PII redaction, structured output, call
limits, and tool selection; fallback models are supported. `partial` marks a
surface that covers the vector behavior and common path but not every optional
Go hook or provider adapter.

| Go symbol | Objective-C symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `PXRMessageCreate` | parity | P1 |
| `model.Request` | `PXRRequestCreate` | parity | P1 |
| `model.Response` | `PXRResponseCreate` | parity | P1 |
| `model.Usage` | `PXRUsageCreate` | parity | P1 |
| `tool.Tool` | `PXRToolCreate` | parity | P1 |
| `tool.Registry` | `PXRAgentOptionsCreate` | partial | P1 |
| `event.Event` | `PXREventCreate` | parity | P1 |
| `event.Sink` | `PXREventSink` | parity | P1 |
| `policy.Decision` | `PXRDecisionCreate` | parity | P1 |
| `policy.PathChecker` | `PXRPathCheckerCreate` | parity | P1 |
| `memory.Store` | `PXRMemoryStoreCreate` | parity | P1 |
| `memory.Record` | `PXRMemoryRecordCreate` | parity | P1 |
| `checkpoint.Allowlist` | `PXRCheckpointAllowlistCreate` | parity | P1 |
| `agent/context.ContextBudget` | `PXRContextBudgetCreate` | parity | P1 |
| `agent/context.EstimateTokens` | `PXREstimateTokens` | parity | P1 |
| `agent.Agent` | `PXRAgentRun` | parity | P1 |
| `agent.Options` | `PXRAgentOptionsCreate` | parity | P1 |
| `agent.New` | `PXRAgentOptionsCreate` | parity | P1 |
| `agent/stream.StreamPart` | `PXRStreamKinds` | partial | P1 |
| `toolcall.ParseToolCall` | `PXRParseToolCall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `PXRStripToolCallMarkup` | parity | P1 |
| `toolcall.ParseInputJSON` | `PXRParseInputJSON` | parity | P1 |
| `tool/jsonschema.Schema` | `PXRValidateSchema` | partial | P1 |
| `plugin.ParseManifest` | `PXRParseManifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `PXRCallLimitCreate` | parity | P1 |
| `agent/middleware.FallbackModel` | `PXRModelCreateFallback` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `PXRPIIRedact` | parity | P1 |
| `agent/middleware.StructuredOutput` | `PXRStructuredOutputCreate` | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `PXRToolSelectionCreate` | parity | P1 |

The JSON, path, pattern, and policy helpers are implementation utilities. See
`language/objc/README.md` for runtime, Unicode, regex, and security limits.
