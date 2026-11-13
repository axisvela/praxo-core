# Java Core Release Notes

## 0.8.0 - 2026-11-13

Source tag `java/v0.8.0`.

### Added

- OpenTelemetry event sink (`adapters.OtelSink`) over a caller-supplied
  OTLP/HTTP transport, with deterministic trace/span identifiers, default
  event-data exclusion, and an explicit data-key allowlist.

## 0.7.1 - 2026-11-12

Source tag `java/v0.7.1`.

### Fixed

- Treat a missing Anthropic `content_block.input` as an empty object so
  text-only stream blocks do not fail parsing.

## 0.7.0 - 2026-11-12

Source tag `java/v0.7.0`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.
- Native Anthropic Messages and Gemini generateContent model adapters.

## 0.5.0 - 2026-11-10

Source tag `java/v0.5.0`. Maven Central publishes the matching artifact after
the release workflow completes.

### Added

- Harmovela lifecycle event sink with an injectable transport.
- Native stdio MCP client, tool adapters, and registry helper.
- API snapshot `api/0.5.0.txt`.

### Changed

- Adapter implementations live under `com.axisvela.praxo.adapters`; Core remains
  free of provider-specific runtime dependencies.

## 0.4.1 - 2026-11-08

Source tag `java/v0.4.1`. Maven Central publishes the matching artifact after
the release workflow completes.

### Changed

- Package metadata and README now describe the published consumer starter,
  governed negative checks, and coding-agent integration guidance.

### Compatibility

- No runtime or public API changes.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.4.0 - 2026-11-02

Source tag `java/v0.4.0`. Maven Central remains at `0.3.0` until publication.

### Added

- Human-in-the-loop interrupt decisions through `AgentOptions.interruptOn`,
  `onInterruptDecision`, and `onInterrupt`.
- `Interrupt`, `InterruptAction`, and `InterruptDecision` with approve/edit/
  reject/respond actions. Interrupted calls emit `tool.interrupt` and edited
  arguments are reauthorized.

### Compatibility

- New options are optional and default to disabled.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
