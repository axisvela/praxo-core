# Nim Core Release Notes

## 0.7.0 - 2026-11-20

Source tag `nim/v0.7.0`.

### Added

- `plugin_process.start` binds the C process host over JSON Lines with
  token authentication.
- Deterministic representative-chain example covering MCP, final-argument
  authorization, governed child delegation, OTel/Harmovela events, and an edited
  denial with zero effects.
- Advanced-delegation example plus six application-level governance checks.

## 0.6.0 - 2026-11-15

Source tag `nim/v0.6.0`.

### Added

- Human-in-the-loop interrupts: `Interrupt`, `InterruptDecision`,
  `InterruptHandler`, `InterruptApproval`, the `INTERRUPT_*` actions,
  `AgentOptions.interruptOn`, `onInterruptDecision`, and `onInterrupt`.
- `AgentOptions.middleware` with `ToolMiddleware` before-tool hooks.
- Tool calls now emit `tool.interrupt` and support approve, edit, reject, and
  respond decisions. Edit reauthorizes replaced arguments before the effect.
- `examples/hitl/` with approve and edited-argument denial scenarios.

### Changed

- `Policy` now receives the full `Action` (`kind`, `sessionId`, `toolName`,
  `arguments`) and returns a `Decision` instead of a boolean. This is a breaking
  change for policy hooks and is intended for the next minor release.

## 0.5.0 - 2026-11-15

Source tag `nim/v0.5.0`.

### Added

- `AgentOptions.requirePolicy` rejects `runAgent` when no policy hook is
  configured.
- `AgentOptions.requireToolScope` rejects `runAgent` when `allowedTools` is
  empty.
- Both guards are opt-in and default to `false`.

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
