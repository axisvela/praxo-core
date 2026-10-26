# PRAXO-CORE Swift SDK

Swift implementation of the PRAXO-CORE contract.

- `SPEC_VERSION`: `0.2.0`
- SDK version: `0.1.0`
- Tier: core
- License: MIT

## Scope

The package implements all eleven conformance vector groups: tool-call
parsing/stripping, the JSON Schema subset, plugin manifest validation, memory,
events, stream kinds, checkpoint envelopes, path policy, context budgets,
middleware, and the agent loop.

`swift/v0.1.0` tagged the wire subset. The core loop is untagged follow-up work;
the API snapshot and provider adapters remain follow-up items.

## Build and test

```bash
swift test
swift run praxo-conformance
```

CI runs both on macOS. The package has no external dependencies.

## Layout

- `Sources/PraxoCore/` library.
- `Sources/PraxoConformance/` wire and core vector runner.
- `Tests/PraxoCoreTests/` XCTest coverage.

## Release

Tag shape: `swift/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
