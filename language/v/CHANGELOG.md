# V Core Release Notes

## Unreleased

### Added

- Deterministic representative-chain example covering MCP, final-argument
  authorization, governed child delegation, OTel/Harmovela events, and an edited
  denial with zero effects.
- Advanced-delegation example plus six application-level governance checks.

## 0.6.0 - 2026-11-15

Source tag `v/v0.6.0`.

### Added

- HITL interrupt decisions and session-checkpoint support.


## 0.5.0 - 2026-11-15

Source tag `v/v0.5.0`.

### Added

- `AgentOptions.require_policy` rejects `run_agent` when no policy hook is
  configured.
- `AgentOptions.require_tool_scope` rejects `run_agent` when `allowed_tools` is
  empty.
- Both guards are opt-in and default to `false`.

## 0.4.8 - 2026-11-13

Source tag `v/v0.4.8`.

### Fixed

- Read OpenTelemetry event data through the object helper.
- Stabilized the OTel sink test and repaired transport-seam verification.

### Commits

- `0308a7f` stabilize OTel sink test
- `15bff10` read OTel event data as a JSON object
- `93e2f48` always read OTel data through the object helper
- `41ec91a` relax OTel attribute assertion

## 0.4.0 - 2026-11-13

Source tag `v/v0.4.0`.

### Added

- OpenTelemetry event sink: OTLP/HTTP span JSON over a caller-supplied
  transport, required endpoint, explicit event-data allowlist, deterministic
  trace and span ids, and bounded `OTEL_HTTP` errors.
- Retriever seam with `Document`, `Retriever`, `FuncRetriever`, and
  `retrieve_documents`; negative limits return `RETRIEVER_INVALID`.
- Synchronous subagent delegation with request/result/task records, terminal
  `completed`/`failed` states, preserved runner error codes, and
  `SUBAGENT_INVALID` for empty parent session or agent ids.

## 0.3.0 - 2026-11-12

Source tag `v/v0.3.0`.

### Added

- Transport-seam MCP client with initialize handshake, paginated tool listing,
  duplicate tool and repeated cursor rejection, typed tool calls, and close.
