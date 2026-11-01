# PHP Core Release Notes

## 0.3.0 - 2026-11-01

Source version `0.3.0`; tag creation is a release step. The Packagist package
remains `axisvela/praxo-core@0.1.0` until publication.

### Added

- Caller-provided `batchToolInvoker` and `maxParallelTools` for bounded
  cooperative parallel tool dispatch.
- API snapshot `api/0.3.0.txt`.

### Compatibility

- New `AgentOptions` fields are additive.
- The Core does not create threads; the batch invoker owns concurrency and the
  native test uses PHP Fibers.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-01

Source release tag `php/v0.2.0`. The Packagist package remains
`axisvela/praxo-core@0.1.0` until publication.

### Added

- `Agent::runStream` and streaming model callbacks.
- Cancellation through `AgentOptions::cancellation`.
- `parseSseStream` for OpenAI-compatible SSE streams.
- API snapshot `api/0.2.0.txt`.

### Fixed

- Final tool names are checked against the allowlist, middleware changes are
  reauthorized, and the final registered tool is executed.
- Middleware entered before a startup failure is cleaned up without run events.
- Later after-run callbacks continue after one fails, and cleanup failures after
  success fail the run closed.
- Truncated and half-packet SSE streams are rejected.

### Compatibility

- New options and methods are backward compatible for callers.
- Parallel tool execution remains unsupported: PHP has no standard threads, and pcntl/parallel extensions are not portable across CLI, FPM, and Windows.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## Earlier Releases

See the repository [changelog](../../CHANGELOG.md) for `0.1.x` history.
