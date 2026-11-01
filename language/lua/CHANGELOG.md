# Lua Core Release Notes

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
