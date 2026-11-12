# Objective-C Core Release Notes

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
