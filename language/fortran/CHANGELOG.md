# Fortran Core Release Notes

## 0.12.0 - 2026-11-26

Source tag `fortran/v0.12.0`.

- Minor release for AI-native reference applications, scenario tutorials, and the Go examples layout refresh.

## 0.11.0 - 2026-11-20

Source tag `fortran/v0.11.0`.

### Added

- Process plugin host and provider streaming updates.

## 0.10.0 - 2026-11-15

Source tag `fortran/v0.10.0`.

### Added

- Transport-seam Anthropic Messages and Gemini generateContent model adapters.
- Opt-in `agent_options` fields `require_policy` and `require_tool_scope` with
  `AGENT_INVALID_OPTIONS` guards for a missing policy hook or an empty allowed
  tool list. Both default to `.false.` and preserve existing behavior.

## 0.9.0 - 2026-11-13

Source release tag `fortran/v0.9.0`. This is not a package-registry release.

### Added

- OpenTelemetry OTLP/HTTP event sink over a caller-supplied transport.
- Document retriever seam (`document`, `retriever`, `retrieve_documents`).
- Synchronous subagent seam (`subagent_run`); no asynchronous manager.

## 0.8.0 - 2026-11-13

Source release tag `fortran/v0.8.0`. This is not a package-registry release.

### Added

- Transport-seam MCP client with initialize, paginated tool listing,
  duplicate-tool and repeated-cursor rejection, tool calls, and close.

## 0.6.0 - 2026-11-02

Source release tag `fortran/v0.6.0`. This is not a package-registry release.

### Added

- Human-in-the-loop interrupt decisions through `agent_options` interrupt
  fields and an `on_interrupt` procedure pointer.
- Approve/edit/reject/respond decisions with `tool.interrupt` events and
  reauthorization of edited arguments. HITL runs use the sequential tool path.
- API snapshot `api/0.6.0.txt`.

## 0.5.0 - 2026-11-01

Source version `0.5.0`; tag creation is a release step.

### Added

- Cancellation callback with model/tool cancellation cleanup.
- Stream parts and `on_stream` callbacks; stream errors fail closed.
- Native `praxo_sse` parser rejecting truncated and half-packet streams.
- Caller-provided `parallel` batch callback for bounded parallel tool dispatch.
- API snapshot `api/0.5.0.txt`.

### Compatibility

- New `agent_options` components are additive.
- Parallel tool execution is delegated to the caller's batch callback; the
  native test verifies batch size and ordered results.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.4.0 - 2026-11-01

Source release tag `fortran/v0.4.0`.

### Added

- Middleware hooks for before-run, after-run, and before-tool.
- Final tool-name allowlist checks and reauthorization of middleware changes.
- Lifecycle cleanup for startup failures, after-run continuation, and fail-closed
  cleanup errors.
- API snapshot `api/0.4.0.txt`.

### Compatibility

- New `agent_options` components are additive.
- Cancellation, streaming, SSE, parallel tools, and run-state isolation remain
  unsupported.
- The Core contract remains `SPEC_VERSION` `0.2.0`.