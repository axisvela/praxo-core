# Objective-C Core Release Notes

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
