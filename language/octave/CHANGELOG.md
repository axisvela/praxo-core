# Changelog

## 0.8.0 - 2026-11-20

Source tag `octave/v0.8.0`.

### Fixed

- Sort shared API filenames case-insensitively so the `PluginProcess` class
  has the same snapshot position on Windows and Linux. A regression test covers
  both MATLAB and Octave snapshot generators.

### Added

- Representative-chain and advanced-delegation wrappers for the shared
  MATLAB/Octave implementation.

## 0.7.0 - 2026-11-15

Source tag `octave/v0.7.0`.

### Added

- HITL interrupt decisions and session-checkpoint support.


## 0.6.0 - 2026-11-15

Source tag `octave/v0.6.0`.

- Add opt-in `agent_options` fields `requirePolicy` and `requireToolScope` with
  `AGENT_INVALID_OPTIONS` guards for a missing `policy` hook or an empty
  `allowedTools` list. Both default to `false` and preserve existing behavior.

## 0.5.0 - 2026-11-13

- Add an OpenTelemetry OTLP/HTTP sink over a caller-supplied transport with an
  explicit data allowlist, deterministic trace and span IDs, and bounded
  `OTEL_HTTP` errors.
- Add a document and function-handle retriever seam with query and limit
  validation.
- Add a synchronous subagent request/result/task seam with terminal states and
  error-code preservation.
