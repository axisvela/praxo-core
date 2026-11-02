# C# Core Release Notes

## 0.3.0 - 2026-11-02

Source release tag `csharp/v0.3.0`. The tag workflow published
`Praxo.Core@0.3.0` on NuGet.

### Added

- `Interrupt`, `InterruptAction`, `InterruptDecision`, `IInterruptHandler`, and
  `IInterruptApproval`.
- `AgentOptions.InterruptOn`, `OnInterruptDecision`, and `OnInterrupt`.
  Interrupted calls emit `tool.interrupt`, edited arguments are reauthorized,
  and reject/respond follow the Core contract.

## 0.2.0 - 2026-11-01

Source release tag `csharp/v0.2.0`. The NuGet package remains `Praxo.Core@0.1.2`
until publication.

### Added

- `Agent.RunStream` for streaming agent runs.
- `AgentOptions.CancellationToken` for cooperative cancellation.
- `AgentOptions.MaxParallelTools` for bounded parallel tool execution.
- Completion and half-packet validation for OpenAI-compatible SSE streams.
- API coverage for the C# Behavior Lab scenarios.

### Fixed

- Final tool names are checked against the allowlist, middleware changes are
  reauthorized, and the final registered tool is executed.
- Middleware entered before a startup failure is cleaned up without run events.
- Later after-run callbacks continue after one fails, and cleanup failures after
  success fail the run closed.
- Parallel tools preserve result and after-tool order.

### Compatibility

- Additive options and methods are backward compatible for callers.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## Earlier Releases

See the repository [changelog](../../CHANGELOG.md) for `0.1.x` history.
