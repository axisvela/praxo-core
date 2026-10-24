# Compatibility

## Versioning

- `v2` uses the `github.com/axisvela/praxo-core/v2` module path.
- v1 remains available for consumers that have not migrated.
- The v2 exported API is functionally identical to v1.7.0; see
  [v2 migration](11-migration-v2.md).
- `2.1.0` is additive outside `pkg/...`; the exported `pkg/...` API remains
  identical to `2.0.0`.
- `2.2.0` is additive outside `pkg/...`; the exported `pkg/...` API remains
  identical to `2.1.0`.
- `2.3.0` adds `SubagentManager.Wait` and `SubagentManager.Prune`; all other
  exported `pkg/...` declarations are unchanged.
- `2.3.1` is a patch release; the exported `pkg/...` API is identical to
  `2.3.0`.
- `2.3.2` is a patch release; the exported `pkg/...` API is identical to
  `2.3.1`.
- `2.3.3` is a patch release; the exported `pkg/...` API is identical to
  `2.3.2`. Changed final tool calls require fresh policy approval, and arguments
  must remain JSON-serializable when policy is enabled.
- `2.3.4` is a patch release; the exported `pkg/...` API is identical to
  `2.3.3`. Typed schemas reject null, `pattern` uses Go/RE2 regular expressions,
  and length limits count Unicode code points.
- `2.3.5` is a patch release; the exported `pkg/...` API is identical to
  `2.3.4`. Disabling a schedule waits for an in-flight dispatch to finish.
- `2.3.6` is a patch release; the exported `pkg/...` API is identical to
  `2.3.5`. Empty formatter commands return an error, formatter registry slices
  are copied, and `FormatAll` returns walk errors.

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

CI and releases are verified with Go `1.26.10`. The root module's `go 1.25.0`
directive is a language/module minimum, not the tested security baseline or the
minimum for every independent adapter. Use the recommended toolchain for the
quickstart, adapters, and published consumer checks.

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
