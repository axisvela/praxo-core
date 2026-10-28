# Core Contract and Design

Go is the reference implementation. [`spec/`](https://github.com/axisvela/praxo-core/tree/main/spec)
is the normative contract; Core implementations provide idiomatic APIs without changing its wire
names or declared behavior. A disagreement between the reference and the spec
is a bug, not a license to silently fork the contract.

## Contract Layers

| Layer | Requirement |
| --- | --- |
| Wire | Preserve field names, casing, event kinds, error codes, and envelopes |
| Behavior | Pass the shared vectors for the declared implementation scope |
| API | Map declared interfaces and options to idiomatic language constructs |
| Conformance | Run vectors, parity, API checks, and language-specific tests |

Preserve mixed wire casing such as `image_url`, `runId`, and `plugin_id`.
See the [event reference](../reference/events.md), shared wire artifacts, and
per-language parity inventories. Do not normalize wire names for local style.

## Change Workflow

1. Review the reference behavior and normative artifacts.
2. Update wire definitions and vectors when changing the contract.
3. Update the applicable parity inventory.
4. Verify the reference implementation against the vectors.
5. Implement the Core change and run its conformance and API checks.
6. Document supported scope, version compatibility, and limitations.

Do not widen the Go `pkg/...` API merely to support a Core implementation. Concrete integrations
are optional and do not imply cross-language availability.

## Versions and Compatibility

`spec/SPEC_VERSION` versions the shared contract independently of Core releases.
A wire field, event, stream kind, plugin envelope, or error-code change must
update the specification and be evaluated as breaking for every affected Core.
See [compatibility policy](../project/compatibility-policy.md) and
[API stability](../project/api-stability.md).

The shared contract is not a promise that all Core implementations expose every reference
feature. Consult the [support policy](../languages/support.md) and Core-specific API.

## Security and Licensing

Core implementations remain MIT; dependencies require compatible licenses. Credentials and
tenant data stay in caller configuration. Product-owned trust roots, deployment,
and plugin materialization do not belong in framework implementations.
Re-test security-sensitive behavior in each language.

See [language implementation policy](language-policy.md) for implementation
types and contribution gates.
