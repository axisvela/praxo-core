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

## API Stability

Exported interfaces are the stable surface. Concrete adapters and internal
helpers may change between minor versions.

Canonical package paths added in `0.16.0` are `pkg/toolcall`, `pkg/formatter`,
and `pkg/tool/jsonschema`. The previous paths (`pkg/output`, `pkg/format`,
`pkg/tool/schema`) are deprecated aliases. PRAXOVELA migrated in `0.16.0`;
the aliases are removed in `1.0.0` as tracked in
[API freeze inventory](07-api-freeze.md).

The frozen plugin v1 surfaces are:

- Manifest v1 (`pkg/plugin.ParseManifest`)
- contract kinds and the `Host.Invoke` boundary
- the lifecycle transition table
- the guarded `AdapterRegistry`
- process/WASM wire envelopes
- the contract-level TCK

Materialization, signature verification, SBOM/evidence, trust stores, and
rolling updates are product-owned and may evolve independently.

## Compatibility Tests

Each consumer should maintain:

- compile-time interface conformance
- a smoke test for the agent loop
- a policy-denial test
- an event-sink test
- a memory-adapter test where used
- plugin host conformance through `pkg/plugin/tck` where used
