# TypeScript Core Release Notes

## 0.3.0 - 2026-11-10

Source tag `typescript/v0.3.0`. npm publishes `@axisvela/praxo-core@0.3.0` as
`latest`.

### Added

- Harmovela HTTP event sink in `src/adapters/harmovela.ts`.
- stdio MCP client in `src/adapters/mcp.ts` with fake-server tests.
- Adapter sources remain under `src/adapters/`.

### Compatibility

- Additive; the `0.2.2` public API remains available.

## 0.2.2 - 2026-11-08

Source tag `typescript/v0.2.2`. The tag workflow stages the npm package.

### Changed

- Registry README links now use absolute GitHub URLs so npm renders working
  `REGISTRY.md`, `llms.txt`, and `llms.md` links.

### Compatibility

- No runtime or public API changes.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

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
