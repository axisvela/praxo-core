# Swift Core Release Notes

## 0.6.0 - 2026-11-15

Source tag `swift/v0.6.0`.

### Added

- `AgentOptions.requirePolicy` rejects `Agent` construction when no policy hook
  is configured.
- `AgentOptions.requireToolScope` rejects `Agent` construction when
  `allowedTools` is empty.
- Both guards are opt-in and default to `false`.

## 0.5.0 - 2026-11-13

Source tag `swift/v0.5.0`.

### Added

- OpenTelemetry OTLP/HTTP sink over an injected `OtelTransport`.
- Retriever document/query/limit seam with `FuncRetriever`.
- Synchronous subagent delegation seam with `SubagentManager`.

## 0.4.0 - 2026-11-12

Source tag `swift/v0.4.0`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.
