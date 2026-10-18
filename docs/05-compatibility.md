# Compatibility

## Versioning

- Framework versions start at `0.x`.
- PRAXOVELA product versions are independent.
- External consumers declare the supported framework range.
- Breaking changes require a minor bump before `1.0.0`.

## Consumer Matrix

| Consumer | Expected integration |
| --- | --- |
| PRAXOVELA | embeds framework primitives; remains AGPL |
| external products | direct interface implementations |
| COORDIVELA | independent; does not consume this framework |

## API Stability

Exported interfaces are the stable surface. Concrete adapters and internal
helpers may change between minor versions.

## Compatibility Tests

Each consumer should maintain:

- compile-time interface conformance
- a smoke test for the agent loop
- a policy-denial test
- an event-sink test
- a memory-adapter test where used
