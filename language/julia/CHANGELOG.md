# Julia Core Release Notes

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
