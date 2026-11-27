# Erlang Core Release Notes

## 0.10.1 - 2026-11-27

Source tag `erlang/v0.10.1`.

### Changed

- Publish the README's scenario tutorials, reference-application status, and
  community links on the Hex page. No public API or wire change.

## 0.10.0 - 2026-11-26

Source tag `erlang/v0.10.0`.

- Minor release for AI-native reference applications, scenario tutorials, and the Go examples layout refresh.

## 0.9.0 - 2026-11-20

Source tag `erlang/v0.9.0`.

### Added

- Process plugin host and provider streaming updates.

## 0.8.2 - 2026-11-18

Source tag `erlang/v0.8.2`; Hex publication follows the release workflow.

### Added

- Representative-chain, advanced-delegation, and the expanded task-oriented
  example index, including MCP, OTel/Harmovela, and governance checks.
- Registry README links for the current example set.

### Compatibility

- No public API or wire change; `SPEC_VERSION` remains `0.2.0`.


## 0.8.1 - 2026-11-15

### Changed

- Expanded the registry README with a Get started section and a task-oriented example index.

## 0.8.0 - 2026-11-15

Source tag `erlang/v0.8.0`.

### Added

- Opt-in `require_policy` guard: `run_agent/3` returns
  `AGENT_INVALID_OPTIONS` when a policy is required but no policy hook is
  configured.
- Opt-in `require_tool_scope` guard: `run_agent/3` returns
  `AGENT_INVALID_OPTIONS` when tool scope is required but `allowed_tools` is
  empty.

## 0.7.1 - 2026-11-12

Source tag `erlang/v0.7.1`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.
- Native Anthropic Messages and Gemini generateContent model adapters.
- Minimal stdio MCP client with pagination, tool calls, timeouts, and cancellation notifications.

### Changed

- Adapter sources live under `src/adapters/`; public module names are
  unchanged.

## 0.4.0 - 2026-11-02

Source release tag `erlang/v0.4.0`. The Hex package
`praxo_core_erlang==0.4.0` is published from that tag via interactive 2FA OTP.

### Added

- Human-in-the-loop interrupt decisions through `interrupt_on`,
  `on_interrupt_decision`, and `on_interrupt`.
- Approve/edit/reject/respond decisions with `tool.interrupt` events and
  reauthorization of edited arguments.
- API snapshot `api/0.4.0.txt`.

## 0.3.1 - 2026-11-01

Source version `0.3.1`; tag creation is a release step.

### Fixed

- Align `src/praxo_core.app.src` `vsn`, `VERSION`, and `sdk_version()` with the
  published source version.

### Compatibility

- No runtime behavior change from `0.3.0`.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.3.0 - 2026-11-01

Source version `0.3.0`; tag creation is a release step.

### Added

- Cancellation option with model/tool cancellation cleanup.
- Stream parts and `on_stream` callbacks; stream errors fail closed.
- Native `praxo_sse:parse/1` parser rejecting truncated and half-packet streams.
- Bounded parallel tool execution through spawned processes and
  `max_parallel_tools`.
- API snapshot `api/0.3.0.txt`.

### Compatibility

- New agent option keys are additive.
- The Hex package remains `praxo_core_erlang@0.1.1` until publication.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-01

Source release tag `erlang/v0.2.0`. The Hex package remains
`praxo_core_erlang@0.1.1` until publication.

### Added

- Policy hooks and middleware hooks for before-run, after-run, and before-tool.
- Final tool-name allowlist checks and reauthorization of middleware changes.
- Lifecycle cleanup for startup failures, after-run continuation, and fail-closed
  cleanup errors.
- API snapshot `api/0.2.0.txt`.

### Compatibility

- New agent option keys are additive.
- Cancellation, streaming, SSE, parallel tools, and run-state isolation remain
  unsupported.
- The Core contract remains `SPEC_VERSION` `0.2.0`.