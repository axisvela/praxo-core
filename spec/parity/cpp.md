# C++ Parity

- Tier: core
- SPEC_VERSION: 0.2.0

`cpp/v0.3.0` ships the core loop with middleware/lifecycle authorization,
cancellation, stream callbacks, a native SSE parser, bounded parallel tools,
and run-scoped call limits. The Core passes all eleven vector groups, its core
tests, and its public API snapshot. `partial` marks a surface that covers the
vector behavior and common path but not every optional Go hook or provider
adapter.

| Go symbol | C++ symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Message` | `Message` | parity | P1 |
| `model.Request` | `Request` | parity | P1 |
| `model.Response` | `Response` | parity | P1 |
| `model.Usage` | `Usage` | parity | P1 |
| `tool.Tool` | `Tool` | parity | P1 |
| `tool.Registry` | `ToolRegistry` | parity | P1 |
| `event.Event` | `Event` | parity | P1 |
| `event.Sink` | `EventSink` | parity | P1 |
| `policy.Decision` | `Decision` | parity | P1 |
| `policy.PathChecker` | `PathChecker` | parity | P1 |
| `memory.Store` | `MemoryStore` | parity | P1 |
| `memory.Record` | `MemoryRecord` | parity | P1 |
| `checkpoint.Allowlist` | `CheckpointAllowlist` | parity | P1 |
| `agent/context.ContextBudget` | `ContextBudget` | parity | P1 |
| `agent/context.EstimateTokens` | `estimate_tokens` | parity | P1 |
| `agent.Agent` | `Agent` | parity | P1 |
| `agent.Options` | `AgentOptions` | parity | P1 |
| `agent.New` | `Agent::Agent` | parity | P1 |
| `agent/stream.StreamPart` | `StreamPart` | parity | P2 |
| `agent.StatusCancelled` | `AgentOptions::cancellation`, `AGENT_CANCELLED` | partial | P2 |
| `agent.Options.OnStream` | `AgentOptions::on_stream` | partial | P2 |
| `agent.Options.MaxParallelTools` | `AgentOptions::max_parallel_tools` | partial | P2 |
| `toolcall.ParseToolCall` | `parse_toolcall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `strip_markup` | parity | P1 |
| `toolcall.ParseInputJSON` | `parse_input_json` | parity | P1 |
| `tool/jsonschema.Schema` | `validate` | partial | P1 |
| `plugin.ParseManifest` | `parse_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `CallLimit` (run-scoped) | parity | P1 |
| `agent/middleware.FallbackModel` | `fallback_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `PiiRedactor` | parity | P1 |
| `agent/middleware.StructuredOutput` | `StructuredOutput` | parity | P1 |

Core-local utility with no direct Go contract symbol: `parse_sse_stream` parses
OpenAI-compatible server-sent-event text and throws `MODEL_STREAM` for truncated
streams or malformed half packets. Parallel tool execution uses `std::async`
inside `Agent`; tool implementations remain responsible for their own thread
safety.
| `agent/middleware.ToolSelectionMiddleware` | `ToolSelection` | parity | P1 |
| `agent/hitl.Interrupt` | `Interrupt` | parity | P2 |
| `agent/hitl.InterruptAction` | `InterruptAction` | parity | P2 |
| `agent/hitl.InterruptDecision` | `InterruptDecision` | parity | P2 |
| `agent/hitl.InterruptHandler` | `AgentOptions::on_interrupt_decision` | parity | P2 |
| `agent.Options.OnInterrupt` | `AgentOptions::on_interrupt` | parity | P2 |
