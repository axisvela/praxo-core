# COBOL Core Release Notes

## 0.4.0 - 2026-11-02

Source release tag `cobol/v0.4.0`. This is not a package-registry release.

### Added

- Human-in-the-loop interrupt decisions through `px-interrupt-program`,
  `px-interrupt-count`, and `px-interrupt-tools`.
- A `px-interrupt` callback record supports approve/edit/reject/respond.
  Interrupted calls emit `tool.interrupt`; edited arguments are reauthorized.
- API snapshot `api/0.4.0.txt`.

## 0.3.0 - 2026-11-01

Source version `0.3.0`; tag creation is a release step.

### Added

- Cancellation callback program with model and tool cancellation cleanup.
- Stream callback parts (`values`, `messages`) and fail-closed stream errors.
- Native `praxo-sse` parser that rejects truncated and half-packet streams.
- Caller-provided batch tool dispatcher with `px-max-parallel-tools`, ordered
  results, and `tool-batch.cpy`.
- Native behavior and SSE suites; all nineteen behavior scenarios are covered.
- API snapshot `api/0.3.0.txt`.

### Compatibility

- New `px-options` components are additive; consumers must recompile against the
  new copybook.
- Parallel tool execution is delegated to the batch dispatcher. The native test
  verifies the batch limit and result order, not OS-level thread concurrency.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-01

Source version `0.2.0`; tag creation is a release step.

### Added

- Optional before-run, after-run, and before-tool callback programs in
  `px-options`.
- Final tool-name allowlist checks and reauthorization of middleware-mutated
  names or arguments.
- Lifecycle cleanup for startup failures, after-run continuation, and
  fail-closed cleanup errors.
- Native behavior cases for the seven authorization and lifecycle scenarios.
- API snapshot `api/0.2.0.txt`.

### Compatibility

- New `px-options` components are additive; consumers must recompile against the
  new copybook.
- Cancellation, streaming, SSE, parallel tools, and run-state isolation remain
  unsupported.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
