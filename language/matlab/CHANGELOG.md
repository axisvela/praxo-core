# MATLAB Core Release Notes

## 0.5.0 - 2026-11-13

Source tag `matlab/v0.5.0`.

### Added

- Transport-seam OpenTelemetry OTLP/HTTP sink `praxo.otel_sink` and
  `praxo.otel_emit` with allowlisted event data, deterministic trace and span
  IDs, and bounded `OTEL_HTTP` errors.
- Document retriever seam with `praxo.document` and
  `praxo.retrieve_documents`; negative limits raise `RETRIEVER_INVALID`.
- Synchronous subagent delegation seam with `praxo.subagent_request`,
  `praxo.subagent_result`, `praxo.subagent_task`, and `praxo.subagent_run`;
  invalid parent session or agent IDs raise `SUBAGENT_INVALID`.

## 0.4.0 - 2026-11-12

Source tag `matlab/v0.4.0`.

### Added

- Transport-seam MCP client with `praxo.mcp_client`, `praxo.mcp_list_tools`,
  `praxo.mcp_call_tool`, and `praxo.mcp_close`.
