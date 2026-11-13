# Nim Core Release Notes

## 0.4.0 - 2026-11-13

Source tag `nim/v0.4.0`.

### Added

- Transport-seam OpenTelemetry OTLP/HTTP sink `newOtelSink` with allowlisted
  event data, deterministic trace and span IDs, and bounded `OTEL_HTTP` errors.
- Document retriever seam with `Document`, `Retriever`, `FuncRetriever`, and
  `retrieveDocuments`; negative limits raise `RETRIEVER_INVALID`.
- Synchronous subagent delegation seam with `SubagentRequest`, `SubagentResult`,
  `SubagentTask`, and `subagentRun`; invalid parent session or agent IDs raise
  `SUBAGENT_INVALID`.

## 0.3.0 - 2026-11-12

Source tag `nim/v0.3.0`.

### Added

- Transport-seam MCP client with initialize handshake, paginated tool listing,
  duplicate tool and repeated cursor rejection, typed tool calls, and close.
