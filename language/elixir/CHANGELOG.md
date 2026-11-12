# Elixir Core Release Notes

## 0.7.0 - 2026-11-12

Source tag `elixir/v0.7.0`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.
- Native Anthropic Messages and Gemini generateContent model adapters.

## 0.5.1 - 2026-11-10

Source release tag `elixir/v0.5.1`. Hex publishes `praxo_core==0.5.1` and
HexDocs `0.5.1` through `.github/workflows/elixir-release.yml`.

### Fixed

- Release workflow compiles `lib/praxo/adapters/` before running tests.
- API snapshot `api/0.5.1.txt`.

## 0.5.0 - 2026-11-10

Source release tag `elixir/v0.5.0` failed before publication because the
release workflow did not compile adapter modules. Superseded by `0.5.1`.

### Added

- Harmovela HTTP event sink with an injectable transport.
- Native stdio MCP client, tool adapters, and registry helper.
- API snapshot `api/0.5.0.txt`.

### Changed

- Adapter implementations live under `lib/praxo/adapters/`; Core remains free
  of provider-specific runtime dependencies.
- MCP default client version is `0.5.0`.

## 0.4.1 - 2026-11-09

Source release tag `elixir/v0.4.1`. Hex publishes `praxo_core==0.4.1` and
HexDocs `0.4.1` through `.github/workflows/elixir-release.yml`.

### Added

- Optional `Praxo.OpenAICompatible` adapter. It is additive and not required by
  the Core.
- API snapshot `api/0.4.1.txt`.

## 0.4.0 - 2026-11-02

Source release tag `elixir/v0.4.0`. The Hex package `praxo_core==0.4.0` is
published from that tag via interactive 2FA OTP.

### Added

- Human-in-the-loop interrupt decisions through `AgentOptions.interrupt_on`,
  `on_interrupt_decision`, and `on_interrupt`.
- `Praxo.Interrupt` and `Praxo.InterruptDecision` with approve/edit/reject/
  respond actions. Interrupted calls emit `tool.interrupt` and edited arguments
  are reauthorized.
- API snapshot `api/0.4.0.txt`.

## 0.3.0 - 2026-11-01

Source version `0.3.0`; tag creation is a release step.

### Added

- Cancellation option with model/tool cancellation cleanup.
- Stream parts and `on_stream` callbacks; stream errors fail closed.
- Native `Praxo.SSE.parse/1` parser rejecting truncated and half-packet streams.
- Bounded parallel tool execution through `max_parallel_tools`.
- API snapshot `api/0.3.0.txt`.

### Compatibility

- New `AgentOptions` fields are additive.
- The Hex package remains `praxo_core@0.1.1` until publication.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-01

Source release tag `elixir/v0.2.0`. The Hex package remains `praxo_core@0.1.1`
until publication.

### Added

- Policy hooks and middleware hooks for before-run, after-run, and before-tool.
- Final tool-name allowlist checks and reauthorization of middleware changes.
- Lifecycle cleanup for startup failures, after-run continuation, and fail-closed
  cleanup errors.
- API snapshot `api/0.2.0.txt`.

### Compatibility

- New `AgentOptions` fields are additive.
- Cancellation, streaming, SSE, parallel tools, and run-state isolation remain
  unsupported.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
