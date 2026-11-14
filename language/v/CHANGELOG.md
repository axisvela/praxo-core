# V Core Release Notes

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
