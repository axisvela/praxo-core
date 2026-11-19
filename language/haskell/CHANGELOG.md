# Haskell Core Release Notes

## 0.8.0 - 2026-11-20

Source tag `haskell/v0.8.0`.

### Added

- Process plugin host and provider streaming updates.

## 0.7.1 - 2026-11-18

Source tag `haskell/v0.7.1`; Hackage publication follows the release workflow.

### Added

- Deterministic representative-chain example covering MCP, final-argument
  authorization, governed child delegation, OTel/Harmovela events, and an edited
  denial with zero effects.
- Advanced-delegation example plus six application-level governance checks.

### Compatibility

- No public API or wire change; `SPEC_VERSION` remains `0.2.0`.

## 0.7.0 - 2026-11-15

Source tag `haskell/v0.7.0`.

### Added

- HITL interrupt decisions and session-checkpoint support.



## 0.6.1 - 2026-11-15

### Changed

- Expanded the registry README with a Get started section and a task-oriented example index.

## 0.6.0 - 2026-11-15

Source tag `haskell/v0.6.0`.

### Added

- `AgentOptions.requirePolicy` rejects `runAgent` when no policy hook is
  configured.
- `AgentOptions.requireToolScope` rejects `runAgent` when `allowedTools` is
  empty.
- Both guards are opt-in and default to `false`.

## 0.5.0 - 2026-11-13

Source tag `haskell/v0.5.0`; Hackage publishes `praxo-core==0.5.0` from that tag.

### Added

- OpenTelemetry transport-seam sink with caller-supplied delivery.
- Retriever seam with `Document`, `Retriever`, and synchronous delegation helpers.

### Changed

- Kept all eleven shared vector groups, native regression tests, and source
  API/parity checks green for the release.
