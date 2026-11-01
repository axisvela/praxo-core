# R Core Release Notes

## 0.3.0 - 2026-11-01

Source release tag `r/v0.3.0`.

### Added

- Policy hooks and middleware in the agent loop.
- Final tool-name allowlist checks and reauthorization of middleware changes.
- Lifecycle cleanup for startup failures, after-run continuation, and fail-closed
  cleanup errors.
- Cooperative cancellation checks during model and tool work.
- Streaming model callbacks through `agent_run`.
- `parse_sse_stream` for OpenAI-compatible SSE streams.
- API snapshot `api/0.3.0.txt`.

### Fixed

- Initial policy denial now precedes middleware and tool effects.
- Unchanged tool calls are authorized once.

### Compatibility

- New arguments are optional and do not change existing calls.
- Parallel tool execution remains unsupported in this release.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## Earlier Releases

See the repository [changelog](../../CHANGELOG.md) for `0.2.x` history.
