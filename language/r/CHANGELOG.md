# R Core Release Notes

## Unreleased

### Added

- `agent_run` accepts `session` or `messages` for multi-turn history and returns
  the updated `messages` in its result.
- Consumer starter (`examples/consumer`) and OpenAI-compatible live-model
  example (`examples/live-model`).

## 0.9.0 - 2026-11-13

Source tag `r/v0.9.0`.

### Added

- Document retriever seam (`document`, `func_retriever`, `retriever_retrieve`).
- Synchronous subagent seam (`subagent_request`, `subagent_result`,
  `subagent_run`); asynchronous lifecycle management remains outside this
  package.

## 0.8.0 - 2026-11-13

Source tag `r/v0.8.0`.

### Added

- OpenTelemetry event sink (`otel_sink`) over a caller-supplied OTLP/HTTP
  transport, with deterministic trace/span identifiers, default event-data
  exclusion, and an explicit data-key allowlist.

## Unreleased

### Added

- Native Anthropic Messages and Gemini generateContent model adapters.

## 0.6.1 - 2026-11-10

Source release tag `r/v0.6.1`.

### Fixed

- `tests/mcp_tests.R` loads the installed package or repository sources when
  run directly by `R CMD check`.
- API snapshot `api/0.6.1.txt`.

## 0.6.0 - 2026-11-10

Source release tag `r/v0.6.0` failed `R CMD check` before publication.
Superseded by `0.6.1`.

### Added

- OpenAI-compatible model adapter with an injectable transport.
- Harmovela HTTP event sink with an injectable transport.
- Native stdio MCP client, tool adapters, and registry helper.
- API snapshot `api/0.6.0.txt`.

### Changed

- MCP default client version is `0.6.0`.

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
