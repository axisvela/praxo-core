# Python Core Release Notes

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
