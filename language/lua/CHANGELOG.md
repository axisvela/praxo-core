# Lua Core Release Notes

## 0.3.0 - 2026-11-01

Source version `0.3.0`; tag creation is a release step.

### Added

- Cancellation option with model/tool cancellation cleanup.
- Stream parts and `on_stream` callbacks; stream errors fail closed.
- Native `praxo.sse.parse` parser rejecting truncated and half-packet streams.
- Caller-provided `batch_invoke` for bounded cooperative parallel tools.
- API snapshot `api/0.3.0.txt`.
- Source rockspec `0.3.0-1`.

### Compatibility

- New `agent_options` fields are additive.
- Parallel tool concurrency is provided by the caller's `batch_invoke`; the
  native test uses a cooperative coroutine scheduler.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-01

Source release tag `lua/v0.2.0`.

### Added

- Middleware hooks for before-run, after-run, and before-tool.
- Final tool-name allowlist checks and reauthorization of middleware changes.
- Lifecycle cleanup for startup failures, after-run continuation, and fail-closed
  cleanup errors.
- API snapshot `api/0.2.0.txt`.
- Source rockspec `0.2.0-1`.

### Compatibility

- New `agent_options` fields are additive.
- Cancellation, streaming, SSE, parallel tools, and run-state isolation remain
  unsupported.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
