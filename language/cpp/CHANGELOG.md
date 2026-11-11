# C++ Core Release Notes

## Unreleased

### Added

- Transport-seam Anthropic Messages and Gemini generateContent model adapters.

## 0.4.0 - 2026-11-02

Source release tag `cpp/v0.4.0`.

### Added

- Human-in-the-loop interrupt decisions through
  `AgentOptions::interrupt_on`, `on_interrupt_decision`, and `on_interrupt`.
- `Interrupt`, `InterruptAction`, and `InterruptDecision` with approve/edit/
  reject/respond actions. Interrupted calls emit `tool.interrupt` and edited
  arguments are reauthorized.
- API snapshot `api/0.4.0.txt`.

## 0.3.0 - 2026-11-01

Source version `0.3.0`; tag creation is a release step.

### Added

- Cancellation callback with model/tool cancellation cleanup.
- Stream parts and an `on_stream` callback; stream errors abort the run.
- Native `parse_sse_stream` parser rejecting truncated and half-packet streams.
- Bounded parallel tool execution through `max_parallel_tools`.
- Run-scoped `CallLimit` counters.
- API snapshot `api/0.3.0.txt`.

### Compatibility

- New `AgentOptions` fields are additive and default to disabled or one tool.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-01

Source release tag `cpp/v0.2.0`.

### Added

- Middleware hooks for before-run, after-run, and before-tool.
- Final tool-name allowlist checks and reauthorization of middleware changes.
- Lifecycle cleanup for startup failures, after-run continuation, and fail-closed
  cleanup errors.
- API snapshot `api/0.2.0.txt`.

### Compatibility

- New `AgentOptions` fields are additive.
- Cancellation, streaming, SSE, parallel tools, and run-state isolation remain
  unsupported.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
