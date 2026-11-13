# Erlang Core Release Notes

## 0.7.1 - 2026-11-12

Source tag `erlang/v0.7.1`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.
- Native Anthropic Messages and Gemini generateContent model adapters.
- Minimal stdio MCP client with pagination, tool calls, timeouts, and cancellation notifications.

### Changed

- Adapter sources live under `src/adapters/`; public module names are
  unchanged.

## 0.4.0 - 2026-11-02

Source release tag `erlang/v0.4.0`. The Hex package
`praxo_core_erlang==0.4.0` is published from that tag via interactive 2FA OTP.

### Added

- Human-in-the-loop interrupt decisions through `interrupt_on`,
  `on_interrupt_decision`, and `on_interrupt`.
- Approve/edit/reject/respond decisions with `tool.interrupt` events and
  reauthorization of edited arguments.
- API snapshot `api/0.4.0.txt`.

## 0.3.1 - 2026-11-01

Source version `0.3.1`; tag creation is a release step.

### Fixed

- Align `src/praxo_core.app.src` `vsn`, `VERSION`, and `sdk_version()` with the
  published source version.

### Compatibility

- No runtime behavior change from `0.3.0`.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.3.0 - 2026-11-01

Source version `0.3.0`; tag creation is a release step.

### Added

- Cancellation option with model/tool cancellation cleanup.
- Stream parts and `on_stream` callbacks; stream errors fail closed.
- Native `praxo_sse:parse/1` parser rejecting truncated and half-packet streams.
- Bounded parallel tool execution through spawned processes and
  `max_parallel_tools`.
- API snapshot `api/0.3.0.txt`.

### Compatibility

- New agent option keys are additive.
- The Hex package remains `praxo_core_erlang@0.1.1` until publication.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-01

Source release tag `erlang/v0.2.0`. The Hex package remains
`praxo_core_erlang@0.1.1` until publication.

### Added

- Policy hooks and middleware hooks for before-run, after-run, and before-tool.
- Final tool-name allowlist checks and reauthorization of middleware changes.
- Lifecycle cleanup for startup failures, after-run continuation, and fail-closed
  cleanup errors.
- API snapshot `api/0.2.0.txt`.

### Compatibility

- New agent option keys are additive.
- Cancellation, streaming, SSE, parallel tools, and run-state isolation remain
  unsupported.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
