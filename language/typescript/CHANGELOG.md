# TypeScript Core Release Notes

## 0.2.1 - 2026-11-08

Source tag `typescript/v0.2.1`. The tag workflow stages the npm package.

### Changed

- Package metadata and README now describe the published consumer starter,
  governed negative checks, and coding-agent integration guidance.

### Compatibility

- No runtime or public API changes.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-02

Source tag `typescript/v0.2.0`. The tag workflow stages the npm package.

### Added

- Human-in-the-loop interrupt decisions through `interruptOn`,
  `onInterruptDecision`, and `onInterrupt`.
- `Interrupt` and `InterruptDecision` with approve/edit/reject/respond actions.
  Interrupted calls emit `tool.interrupt` and edited arguments are reauthorized.

### Compatibility

- New options are optional and default to disabled.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
