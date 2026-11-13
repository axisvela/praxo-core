# Python Core Release Notes

## 0.7.0 - Unreleased

Planned source tag `python/v0.7.0`.

### Added

- OpenTelemetry event sink (`praxo.adapters.otel.OtelSink`) over a
  caller-supplied OTLP/HTTP transport, with default event-data exclusion and an
  explicit data-key allowlist.
- Local subagent delegation (`praxo.delegation.SubagentManager`) with
  launch/check/wait/update/cancel and terminal states.
- Retriever seam (`praxo.retriever.Document`, `Retriever`, `FuncRetriever`).

## 0.6.0 - 2026-11-12

Source tag `python/v0.6.0`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.
- Native Anthropic Messages and Gemini generateContent model adapters.
- OpenAI-compatible provider presets for OpenAI, DeepSeek, Kimi/Moonshot,
  OpenRouter, Groq, and Together.

## 0.4.1 - 2026-11-10

Source tag `python/v0.4.1`. PyPI publishes `praxo-core==0.4.1` from that tag.
This supersedes the `0.4.0` source tag, whose release build failed on an outdated
installed-smoke version assertion.

### Fixed

- `installed_smoke.py` now checks the `0.4.1` package version.

## 0.4.0 - 2026-11-10

Source tag `python/v0.4.0`; PyPI publication is pending. The published package
remains `0.3.2`.

### Added

- Harmovela HTTP event sink in `praxo.adapters.harmovela`.
- stdio MCP client in `praxo.adapters.mcp` with fake-server tests.
- Adapter sources now live under `praxo/adapters/`.

### Compatibility

- Additive; the existing `0.3.2` public API remains available.

## 0.3.2 - 2026-11-08

Source tag `python/v0.3.2`. The PyPI package is published by the tag workflow.

### Changed

- Registry README links now use absolute GitHub URLs so PyPI renders working
  `REGISTRY.md`, `llms.txt`, and `llms.md` links.

### Compatibility

- No runtime or public API changes.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.3.1 - 2026-11-08

Source tag `python/v0.3.1`. The PyPI package is published by the tag workflow.

### Changed

- Package metadata and README now describe the published consumer starter,
  governed negative checks, and coding-agent integration guidance.

### Compatibility

- No runtime or public API changes.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.3.0 - 2026-11-02

Source tag `python/v0.3.0`. The PyPI package is published by the tag workflow.

### Added

- Human-in-the-loop interrupt decisions through `AgentOptions.interrupt_on`,
  `on_interrupt_decision`, and `on_interrupt`.
- `Interrupt` and `InterruptDecision` with approve/edit/reject/respond actions.
  Interrupted calls emit `tool.interrupt` and edited arguments are reauthorized.

### Compatibility

- New options are optional and default to disabled.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
