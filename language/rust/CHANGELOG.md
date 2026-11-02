# Rust Core Release Notes

## 0.3.0 - 2026-11-02

Source release tag `rust/v0.3.0`. The crates.io package remains `0.1.4`.

### Added

- `hitl` module with `Interrupt`, `InterruptAction`, `InterruptDecision`,
  `InterruptHandler`, and `InterruptApproval`.
- `AgentOptions::interrupt_on`, `on_interrupt_decision`, and `on_interrupt`.
  Interrupted calls emit `tool.interrupt`, edited arguments are reauthorized,
  and reject/respond follow the Core contract.
- API snapshot `api/0.3.0.txt`.

## 0.2.0 - 2026-11-01

Source release tag `rust/v0.2.0`. The crates.io package remains `0.1.4` until a
registry publication is completed.

### Added

- `Agent::run_stream` and `AgentOptions::streaming_model` for streaming agent
  runs.
- `CancellationToken` and `AgentOptions::cancellation`.
- `AgentOptions::max_parallel_tools` with bounded tool concurrency.
- `openai_compat::parse_stream`, an SSE parser that rejects truncated and
  half-packet streams.
- API snapshot `api/0.2.0.txt`.

### Changed

- `StreamingModel::generate_stream` now accepts
  `&mut dyn FnMut(&str) -> Result<()>` so callback failures abort the run.
  Implementations must return `Ok(())` from the callback on success.

### Fixed

- Final tool names are checked against the allowlist, middleware-mutated names
  and arguments are reauthorized, and the final registered tool is executed.
- Middleware entered before a startup failure is cleaned up without run events.
- Later after-run callbacks continue after one fails, and cleanup failures after
  success fail the run closed.
- Parallel tools preserve authorization, result, and after-tool order.

### Compatibility

- Additive options and methods are backward compatible for callers.
- The `StreamingModel` callback signature is a breaking change for streaming
  model implementors; update callbacks to return `Result<()>`.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## Earlier Releases

See the repository [changelog](../../CHANGELOG.md) for `0.1.x` history.
