# COBOL Core Release Notes

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
