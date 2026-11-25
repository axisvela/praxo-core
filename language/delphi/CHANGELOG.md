# Delphi/Free Pascal Core Release Notes

## 0.9.0 - 2026-11-26

Source tag `delphi/v0.9.0`.

- Minor release for AI-native reference applications, scenario tutorials, and the Go examples layout refresh.

## 0.8.0 - 2026-11-20

Source tag `delphi/v0.8.0`.

### Added

- `TPraxoPluginProcess` supervises a JSON-Lines plugin child with token
  authentication.
- Deterministic representative-chain example covering MCP, final-argument
  authorization, governed child delegation, OTel/Harmovela events, and an edited
  denial with zero effects.
- Advanced-delegation governance example with six application-level negative
  checks.

## 0.7.0 - 2026-11-15

Source tag `delphi/v0.7.0`.

### Added

- HITL interrupt decisions and session-checkpoint support.


## 0.6.0 - 2026-11-15

Source tag `delphi/v0.6.0`.

### Added

- `PraxoRunAgent` rejects a run with `RequirePolicy = True` when no policy hook
  is configured.
- `PraxoRunAgent` rejects a run with `RequireToolScope = True` when
  `AllowedTools` is empty.
- Both guards are opt-in and default to `False`.

## 0.5.0 - 2026-11-13

Source tag `delphi/v0.5.0`.

### Added

- OpenTelemetry OTLP/HTTP sink over an injected `TPraxoOtelTransport`.
- Retriever document/query/limit seam with `TPraxoDocument` and
  `PraxoRetrieveDocuments`.
- Synchronous subagent delegation seam with `TPraxoSubagentManager`.

## 0.4.0 - 2026-11-12

Source tag `delphi/v0.4.0`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.