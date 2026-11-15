# D Core Release Notes

## 0.6.0 - 2026-11-15

Source tag `d/v0.6.0`.

### Added

- First-class HITL interrupt decisions (`praxo.hitl`) with `approve`, `edit`,
  `reject`, and `respond` actions, `tool.interrupt` events, and
  `AGENT_APPROVAL_DENIED`, `AGENT_INTERRUPT_UNHANDLED`, and
  `AGENT_INTERRUPT_DECISION_INVALID` errors.
- `AgentOptions.interruptOn`, `onInterruptDecision`, `onInterrupt`, and
  before-tool middleware ordering.
- Deterministic HITL core tests and `examples/hitl`.

## 0.5.0 - 2026-11-15

Source tag `d/v0.5.0`.

### Added

- `AgentOptions.requirePolicy` rejects construction without a policy hook.
- `AgentOptions.requireToolScope` rejects construction with an empty
  `allowedTools` list.
- Both guards are opt-in and default to `false`.

## 0.4.0 - 2026-11-13

Source tag `d/v0.4.0`.

### Added

- OpenTelemetry OTLP/HTTP event sink (`praxo.otel.OtelSink`).
- Document retriever seam (`praxo.retriever`).
- Synchronous subagent delegation seam (`praxo.delegation`).

## 0.3.0 - 2026-11-12

Source tag `d/v0.3.0`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.
