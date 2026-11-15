# MATLAB Core Release Notes

## 0.7.0 - 2026-11-15

Source tag `matlab/v0.7.0`.

### Added

- HITL interrupt decisions and session-checkpoint support.


## 0.6.0 - 2026-11-15

Source tag `matlab/v0.6.0`.

### Added

- Opt-in `agent_options` fields `requirePolicy` and `requireToolScope` with
  `AGENT_INVALID_OPTIONS` guards for a missing `policy` hook or an empty
  `allowedTools` list. Both default to `false` and preserve existing behavior.

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
