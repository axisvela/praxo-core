# Zig Core Release Notes

## Unreleased

### Added

- `plugin_process.start`, `plugin_process.invoke`, and `Host.stop` bind the C
  process host over JSON Lines with token authentication and timeout.
- Deterministic representative-chain example covering MCP, final-argument
  authorization, governed child delegation, OTel/Harmovela events, and an edited
  denial with zero effects.
- Advanced-delegation example plus six application-level governance checks.
- `praxo.zig` exposes the existing `delegation`, `harmovela`, and `otel` modules.
- `SubagentTask.error` uses the escaped Zig identifier `@"error"` so the module
  compiles under Zig 0.17.

## 0.7.0 - 2026-11-15

Source tag `zig/v0.7.0`.

### Added

- HITL interrupt decisions and session-checkpoint support.


## 0.6.0 - 2026-11-15

Source tag `zig/v0.6.0`.

### Added

- `AgentOptions.require_policy` rejects a run without a policy hook.
- `AgentOptions.require_tool_scope` rejects a run with an empty
  `allowed_tools` list.
- Both guards are opt-in and default to `false`.

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
