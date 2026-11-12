# Fortran Core Release Notes

## 0.8.0 - 2026-11-13

Source release tag `fortran/v0.8.0`. This is not a package-registry release.

### Added

- Transport-seam MCP client with initialize, paginated tool listing,
  duplicate-tool and repeated-cursor rejection, tool calls, and close.

## Unreleased

### Added

- Transport-seam Anthropic Messages and Gemini generateContent model adapters.

## 0.6.0 - 2026-11-02

Source release tag `fortran/v0.6.0`. This is not a package-registry release.

### Added

- Human-in-the-loop interrupt decisions through `agent_options` interrupt
  fields and an `on_interrupt` procedure pointer.
- Approve/edit/reject/respond decisions with `tool.interrupt` events and
  reauthorization of edited arguments. HITL runs use the sequential tool path.
- API snapshot `api/0.6.0.txt`.

## 0.5.0 - 2026-11-01

Source version `0.5.0`; tag creation is a release step.

### Added

- Cancellation callback with model/tool cancellation cleanup.
- Stream parts and `on_stream` callbacks; stream errors fail closed.
- Native `praxo_sse` parser rejecting truncated and half-packet streams.
- Caller-provided `parallel` batch callback for bounded parallel tool dispatch.
- API snapshot `api/0.5.0.txt`.

### Compatibility

- New `agent_options` components are additive.
- Parallel tool execution is delegated to the caller's batch callback; the
  native test verifies batch size and ordered results.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.4.0 - 2026-11-01

Source release tag `fortran/v0.4.0`.

### Added

- Middleware hooks for before-run, after-run, and before-tool.
- Final tool-name allowlist checks and reauthorization of middleware changes.
- Lifecycle cleanup for startup failures, after-run continuation, and fail-closed
  cleanup errors.
- API snapshot `api/0.4.0.txt`.

### Compatibility

- New `agent_options` components are additive.
- Cancellation, streaming, SSE, parallel tools, and run-state isolation remain
  unsupported.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
