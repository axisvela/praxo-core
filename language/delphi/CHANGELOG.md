# Delphi/Free Pascal Core Release Notes

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
