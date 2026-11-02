# R Core Release Notes

## 0.5.0 - 2026-11-02

Source release tag `r/v0.5.0`.

### Added

- `interrupt`, `interrupt_decision`, and `interrupt_*` action helpers.
- `agent_run` accepts `interrupt_on`, `on_interrupt_decision`, and
  `on_interrupt`. Interrupted calls emit `tool.interrupt`, edited arguments are
  reauthorized, and reject/respond follow the Core contract.
- API snapshot `api/0.5.0.txt`.

## 0.4.0 - 2026-11-01

Source release tag `r/v0.4.0`.

### Added

- `max_parallel_tools` for bounded parallel tool execution.
- Unix uses `parallel::mclapply`; Windows uses a PSOCK cluster.
- Parallel results preserve original tool order.
- API snapshot `api/0.4.0.txt`.

### Compatibility

- New argument is optional and does not change existing calls.
- Windows parallel execution requires a working PSOCK cluster; timing
  characteristics differ from Unix.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

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
