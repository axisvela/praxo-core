# Haskell Core Release Notes

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
