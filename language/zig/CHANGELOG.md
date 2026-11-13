# Zig Core Release Notes

## 0.5.0 - 2026-11-13

Source tag `zig/v0.5.0`.

### Added

- Transport-seam OpenTelemetry OTLP/HTTP sink with allowlisted event data,
  deterministic trace and span IDs, and bounded `OTEL_HTTP` errors.
- Document retriever seam with `Document`, `Retriever`, and
  `retrieveDocuments`; negative limits return `RETRIEVER_INVALID`.
- Synchronous subagent delegation seam with `SubagentRequest`,
  `SubagentResult`, `SubagentTask`, and `subagentRun`; invalid parent session
  or agent IDs return `SUBAGENT_INVALID`.

## 0.4.0 - 2026-11-12

Source tag `zig/v0.4.0`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.
