# Lua Core Release Notes

## 0.6.0 - 2026-11-13

Source tag `lua/v0.6.0`. Rockspec `0.6.0-1`.

### Added

- OpenTelemetry event sink (`adapters.otel_sink`) over a caller-supplied
  OTLP/HTTP transport.
- Retriever seam (`document`, `func_retriever`, `retriever_retrieve`).
- Synchronous delegation seam (`subagent_request`, `subagent_result`,
  `subagent_run`); no asynchronous manager.

## Unreleased

### Added

- Native Anthropic Messages and Gemini generateContent model adapters.
- Transport-seam MCP client with pagination and tool calls.

### Changed

- Adapters live under `praxo/adapters/`. The old
  `praxo.openai_compatible` and `praxo.harmovela_sink` paths remain as
  compatibility wrappers.

## 0.4.1 - 2026-11-09

Source release tag `lua/v0.4.1`. LuaRocks publishes rock revision `0.4.1-1`
through the `lua-release` workflow.

### Added

- Optional `praxo.openai_compatible` adapter, included by the new rockspec.
- API snapshot `api/0.4.1.txt` and rockspec `0.4.1-1`.

## 0.4.0 - 2026-11-02

Source release tag `lua/v0.4.0`. LuaRocks publishes rock revision `0.4.0-1`
through the `lua-release` workflow.

### Added

- Human-in-the-loop interrupt decisions through `interrupt_on`,
  `on_interrupt_decision`, and `on_interrupt`.
- `models.interrupt`, `models.interrupt_decision`, and `INTERRUPT_*` actions.
  Interrupted calls emit `tool.interrupt` and edited arguments are reauthorized.
- API snapshot `api/0.4.0.txt` and rockspec `0.4.0-1`.
- `lua-release` workflow with source-rock build, clean-tree install smoke, and
  LuaRocks publication.

## 0.3.0 - 2026-11-01

Source version `0.3.0`; tag creation is a release step.

### Added

- Cancellation option with model/tool cancellation cleanup.
- Stream parts and `on_stream` callbacks; stream errors fail closed.
- Native `praxo.sse.parse` parser rejecting truncated and half-packet streams.
- Caller-provided `batch_invoke` for bounded cooperative parallel tools.
- API snapshot `api/0.3.0.txt`.
- Source rockspec `0.3.0-1`.

### Compatibility

- New `agent_options` fields are additive.
- Parallel tool concurrency is provided by the caller's `batch_invoke`; the
  native test uses a cooperative coroutine scheduler.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-01

Source release tag `lua/v0.2.0`.

### Added

- Middleware hooks for before-run, after-run, and before-tool.
- Final tool-name allowlist checks and reauthorization of middleware changes.
- Lifecycle cleanup for startup failures, after-run continuation, and fail-closed
  cleanup errors.
- API snapshot `api/0.2.0.txt`.
- Source rockspec `0.2.0-1`.

### Compatibility

- New `agent_options` fields are additive.
- Cancellation, streaming, SSE, parallel tools, and run-state isolation remain
  unsupported.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
