# PRAXO-CORE Swift SDK

Swift implementation of the PRAXO-CORE wire contract.

- `SPEC_VERSION`: `0.2.0`
- SDK version: `0.1.0`
- Tier: wire (toolcall, JSON Schema, plugin manifest)
- License: MIT

## Scope

`0.1.0` implements the wire subset: tool-call parsing/stripping, the JSON
Schema subset, and plugin manifest validation. The core agent loop, middleware,
and provider adapters are follow-up work.

## Build and test

```bash
swift test
swift run praxo-conformance
```

CI runs both on macOS. The package has no external dependencies.

## Layout

- `Sources/PraxoCore/` library.
- `Sources/PraxoConformance/` wire vector runner.
- `Tests/PraxoCoreTests/` XCTest coverage.

## Release

Tag shape: `swift/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
