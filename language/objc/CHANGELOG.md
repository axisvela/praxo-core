# Objective-C Core Release Notes

## 0.8.0 - 2026-11-26

Source tag `objc/v0.8.0`.

- Minor release for AI-native reference applications, scenario tutorials, and the Go examples layout refresh.

## 0.7.0 - 2026-11-20

Source tag `objc/v0.7.0`.

### Added

- `PXRPluginProcess` binds the C process host over JSON Lines with token
  authentication.
- Deterministic representative-chain example covering MCP, final-argument
  authorization, governed child delegation, OTel/Harmovela events, and an edited
  denial with zero effects.
- Advanced-delegation example plus six application-level governance checks.

## 0.6.0 - 2026-11-15

Source tag `objc/v0.6.0`.

### Added

- Human-in-the-loop interrupts: `PXRInterruptCreate`,
  `PXRInterruptDecisionCreate`, the `PXRInterrupt*` action constants,
  `PXRInterruptHandler`, `PXRInterruptApproval`, `PXRToolMiddleware`, and the
  `interruptOn`, `onInterruptDecision`, `onInterrupt`, and `middleware` agent
  options.
- Tool calls now emit `tool.interrupt` and support approve, edit, reject, and
  respond decisions. Edit reauthorizes replaced arguments before the effect.
- `options[@"policy"]` is now invoked with an action dictionary for
  `model.generate`, the original `tool.invoke`, and edited or middleware-modified
  tool calls. Policy blocks return `PXRDecisionCreate(...)`.
- `language/go/examples/hitl/` with approve and edited-argument denial scenarios.

### Changed

- Core `Praxo*.h` and `Praxo*.m` files moved from `language/objc/` to
  `language/objc/src/`. Update direct source builds to add `-Ilanguage/objc/src`
  and prefix core source paths with `src/`. CocoaPods consumers are unaffected.

## 0.5.0 - 2026-11-15

Source tag `objc/v0.5.0`.

### Added

- `PXRAgentOptionsCreate` now defaults the `requirePolicy` and
  `requireToolScope` options to `NO`.
- `requirePolicy` rejects a run without a `policy` hook.
- `requireToolScope` rejects a run without a non-empty `toolSelection` set.
- Both guards are opt-in and default to disabled.

## 0.4.0 - 2026-11-13

Source tag `objc/v0.4.0`.

### Added

- OpenTelemetry OTLP/HTTP sink over an injected `PXROtelTransport`.
- Retriever document/query/limit seam with `PXDocument` and `PXRetriever`.
- Synchronous subagent delegation seam with `PXRSubagentRun`.

## 0.3.1 - 2026-11-12

Source tag `objc/v0.3.1`.

### Fixed

- Guard the stdio MCP transport with `TARGET_OS_IPHONE` so the pod builds for
  iOS; stdio remains available on macOS and other Foundation platforms, while
  iOS uses the HTTP transport.

## 0.3.0 - 2026-11-12

Source tag `objc/v0.3.0`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.