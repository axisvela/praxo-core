# Ruby Core Release Notes

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
