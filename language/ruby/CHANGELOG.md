# Ruby Core Release Notes

## 0.4.0 - 2026-11-02

Source release tag `ruby/v0.4.0`. The RubyGems package remains `0.1.0`.

### Added

- Human-in-the-loop interrupt decisions through `AgentOptions#interrupt_on`,
  `#on_interrupt_decision`, and `#on_interrupt`.
- `Praxo::Models::Interrupt` and `InterruptDecision` with approve/edit/reject/
  respond actions. Interrupted calls emit `tool.interrupt` and edited arguments
  are reauthorized.
- API snapshot `api/0.4.0.txt`.

## 0.3.0 - 2026-11-01

Source version `0.3.0`; tag creation is a release step.

### Added

- Cancellation option with model/tool cancellation cleanup.
- Stream parts and `on_stream` callbacks; stream errors abort the run.
- Native `Praxo::SSE` parser rejecting truncated and half-packet streams.
- Bounded parallel tool execution through `max_parallel_tools`.
- Run-scoped `Middleware::CallLimit` counters.
- API snapshot `api/0.3.0.txt`.

### Compatibility

- New options are optional and default to disabled or one parallel tool.
- The RubyGems package remains `praxo-core@0.1.0` until publication.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-01

Source release tag `ruby/v0.2.0`. The RubyGems package remains
`praxo-core@0.1.0` until publication.

### Added

- Middleware hooks for before-run, after-run, and before-tool.
- Final tool-name allowlist checks and reauthorization of middleware changes.
- Lifecycle cleanup for startup failures, after-run continuation, and fail-closed
  cleanup errors.
- API snapshot `api/0.2.0.txt`.

### Compatibility

- New options are optional and default to empty.
- Cancellation, streaming, SSE, parallel tools, and run-state isolation remain
  unsupported in this release.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## Earlier Releases

See the repository [changelog](../../CHANGELOG.md) for `0.1.x` history.
