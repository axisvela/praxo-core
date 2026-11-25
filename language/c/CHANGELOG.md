# C Core Release Notes

## 0.14.0 - 2026-11-26

Source tag `c/v0.14.0`.

- Minor release for AI-native reference applications, scenario tutorials, and the Go examples layout refresh.

## 0.13.0 - 2026-11-20

Source tag `c/v0.13.0`.

### Fixed

- Replace the POSIX process-host placeholder with `posix_spawnp` supervision,
  poll-based response deadlines, bounded socket writes without SIGPIPE, and
  child termination/reaping. This also enables C-host bindings on Linux.
- Keep remote error codes valid after freeing the response JSON arena and free
  the host allocation when the startup health check fails.
- Enable process-host assertions in release builds and give CTest an explicit
  Python interpreter, fixture working directory, and test timeout.

## 0.12.0 - 2026-11-19

Source tag `c/v0.12.0`.

### Added

- Process plugin host over JSON-Lines stdio on Windows and POSIX, with token
  authentication, health handshake, invocation timeout, and typed call errors.
- `praxo_plugin_process.h` public API.

## 0.10.0 - 2026-11-15

Source tag `c/v0.10.0`.

### Added

- `PxAgentOptions.require_policy` rejects a run without an `authorize` policy
  hook.
- `PxAgentOptions.require_tool_scope` rejects a run with an empty
  `allowed_tools` list.
- Both guards are opt-in and default to `false`.
- Transport-seam Anthropic Messages and Gemini generateContent model adapters.

## 0.9.0 - 2026-11-13

Source release tag `c/v0.9.0`.

### Added

- OpenTelemetry OTLP/HTTP event sink over a caller-supplied transport.
- Document retriever seam (`PxDocument`, `PxRetriever`, `px_retrieve`).
- Synchronous subagent seam (`px_subagent_run`); no portable thread manager.

## 0.8.0 - 2026-11-13

Source release tag `c/v0.8.0`.

### Added

- Transport-seam MCP client with initialize, paginated tool listing,
  duplicate-tool and repeated-cursor rejection, tool calls, and close.

## 0.6.0 - 2026-11-02

### Added

- Human-in-the-loop interrupt decisions through
  `PxAgentOptions.interrupt_on`, `interrupt_on_count`, and `on_interrupt`.
- `PxInterruptDecision` supports approve/edit/reject/respond decisions.
  Interrupted calls emit `tool.interrupt`; edited arguments are reauthorized.
- API snapshot `api/0.6.0.txt`.

### Compatibility

- Existing `PxAgentOptions` positional initializers remain valid; new fields are
  appended and default to zero or NULL.

## 0.5.0 - 2026-11-01

Source release tag `c/v0.5.0`.

### Added

- `PxAgentOptions.max_parallel_tools` with bounded parallel tool execution.
- Unix uses pthread workers with per-thread arenas and a JSON result boundary.
- Windows keeps the sequential path.
- API snapshot `api/0.5.0.txt`.
- Parallel design and limits documented in [PARALLEL.md](PARALLEL.md).

### Compatibility

- Existing `PxAgentOptions` positional initializers remain valid; the field is
  appended and defaults to zero.
- Parallel execution requires thread-safe tool callbacks. Cancellation does not
  preempt an already-running batch.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.4.0 - 2026-11-01

Source release tag `c/v0.4.0`.

### Added

- Cooperative cancellation through `PxAgentOptions.cancelled`.
- Streaming model hook through `generate_stream` and `on_delta`.
- `px_parse_sse_stream` for OpenAI-compatible SSE streams.
- Behavior coverage for model/tool cancellation, stream callback failures,
  truncated streams, and half packets.
- API snapshot `api/0.4.0.txt`.

### Compatibility

- Existing `PxAgentOptions` positional initializers remain valid; new fields are
  appended and default to zero.
- Parallel tools remain unsupported: PxArena is not thread-safe, and per-thread arenas plus result serialization are not implemented.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.3.0 - 2026-11-01

Source release tag `c/v0.3.0`.

### Added

- Policy authorization callback for tool invocation.
- Ordered middleware hooks for before-run, after-run, and before-tool.
- Final tool-name allowlist checks and reauthorization of middleware changes.
- Lifecycle cleanup for startup failures, after-run continuation, and fail-closed
  cleanup errors.
- Native-suite coverage for fractional integer schema validation, Unicode string
  length, nested PII tool history, and isolated call-limit state.
- API snapshot `api/0.3.0.txt`.

### Compatibility

- Existing `PxAgentOptions` positional initializers remain valid; new fields are
  appended and default to zero.
- Parallel tools, cancellation, streaming callbacks, and SSE validation remain
  unsupported.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0

Previous source release tag `c/v0.2.0`. See the repository
[changelog](../../CHANGELOG.md) for earlier history.