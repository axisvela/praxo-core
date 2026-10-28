# PRAXO-CORE Swift Core

Swift implementation of the PRAXO-CORE contract.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.2.0`
- Tier: core
- License: MIT

## Scope

`0.2.0` implements all eleven conformance vector groups: tool-call parsing, JSON
Schema, plugin manifests, memory, events, stream kinds, checkpoint envelopes,
path policy, context budgets, middleware, and the agent loop. Provider adapters
remain follow-up work.

## Build and test

```bash
swift test
swift run praxo-conformance
python api-snapshot.py --check
```

CI runs all three on macOS. The package has no external dependencies.

## Layout

- `Sources/PraxoCore/` library.
- `Sources/PraxoConformance/` wire and core vector runner.
- `api-snapshot.py` and `api/` public API snapshot.
- `Tests/PraxoCoreTests/` XCTest coverage.

## Release

Tag shape: `swift/v0.2.0`. The tag targets `SPEC_VERSION` `0.2.0`.
