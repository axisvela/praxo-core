# Java Core Release Notes

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
