# Julia Core Release Notes

## 0.9.0 - 2026-11-26

Source tag `julia/v0.9.0`.

- Minor release for AI-native reference applications, scenario tutorials, and the Go examples layout refresh.

## 0.8.0 - 2026-11-20

Source tag `julia/v0.8.0`.

### Added

- `ProcessHost` supervises a JSON-Lines plugin child with token
  authentication and call timeouts.
- Deterministic representative-chain example covering MCP, final-argument
  authorization, governed child delegation, OTel/Harmovela events, and an edited
  denial with zero effects.
- Advanced-delegation example plus six application-level governance checks.

## 0.7.0 - 2026-11-15

Source tag `julia/v0.7.0`.

### Added

- HITL interrupt decisions and session-checkpoint support.


## 0.6.0 - 2026-11-15

Source tag `julia/v0.6.0`.

### Added

- `AgentOptions(...; require_policy = true)` and `Agent` reject construction
  when no policy hook is configured.
- `AgentOptions(...; require_tool_scope = true)` and `Agent` reject construction
  when `allowed_tools` is empty.
- Both guards are opt-in and default to `false`.

## 0.5.0 - 2026-11-13

Source tag `julia/v0.5.0`.

### Added

- Transport-seam OpenTelemetry OTLP/HTTP sink `otel_sink` with allowlisted
  event data, deterministic trace and span IDs, and bounded `OTEL_HTTP` errors.
- Document retriever seam with `Document`, `Retriever`, `FuncRetriever`, and
  `retrieve_documents`; negative limits raise `RETRIEVER_INVALID`.
- Synchronous subagent delegation seam with `SubagentRequest`, `SubagentResult`,
  `SubagentTask`, and `subagent_run`; invalid parent session or agent IDs raise
  `SUBAGENT_INVALID`.

## 0.4.0 - 2026-11-12

Source tag `julia/v0.4.0`.

### Added

- Transport-seam MCP client with initialize handshake, paginated tool listing,
  duplicate tool and repeated cursor rejection, typed tool calls, and close.

## 0.3.0 - 2026-11-12

Source tag `julia/v0.3.0`.

### Added

- Harmovela event sink, Anthropic and Gemini model adapters, and the public API
  snapshot.