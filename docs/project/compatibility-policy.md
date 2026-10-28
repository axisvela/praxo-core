# Compatibility and Deprecation Policy

**Status:** public policy for the v2 module line. This page defines what
PRAXO-CORE treats as compatible, how additions are reviewed, and how removals
happen.

## Versioning

PRAXO-CORE uses clean semantic versioning:

- `v2.x.y` is the current module line.
- Patch releases fix behavior without changing exported declarations.
- Minor releases add backward-compatible functionality.
- A breaking change requires `v3.0.0` and a new module path.

Optional adapters have independent tags such as `adapters/mcp/v0.3.0`. Their
versions do not imply a core version and vice versa.

## Covered Surface

The compatibility promise covers exported `pkg/...` declarations:

- exported interfaces and their method sets
- exported struct field names, types, and JSON tags
- exported function and method signatures
- exported constants and typed string values
- error sentinels and typed error codes
- documented wire contracts:
  - plugin Manifest v1 and host envelopes
  - event names, payload fields, and stream kinds
  - JSON Schema subset semantics documented in `pkg/tool/jsonschema`
- optional module import paths and their declared minimum core version

Not covered:

- concrete adapters outside the declared adapter surface
- unexported helpers
- examples
- test-only packages
- behavior explicitly marked experimental

## Additive Changes

A minor release may add:

- a new package
- a new function, type, constant, or variable
- a method to a concrete type when it does not change an exported interface
- a new optional interface implemented by an existing type
- a new exported struct field only when the struct is documented for keyed
  literals and the field is optional
- a new optional JSON field or event data key

Adding a method to an exported interface is breaking unless the interface is
explicitly documented as extensible. Prefer a new optional interface.

Adding a field to an exported struct can break unkeyed composite literals.
Treat it as breaking unless the type is documented as keyed-literal-only.

## Breaking Changes

The following require a major release:

- removing or renaming an exported declaration
- changing a function or method signature
- changing an exported interface method set
- removing or renaming a struct field or JSON tag
- changing a typed constant string value or error sentinel
- changing event type strings, stream kinds, plugin manifest fields, or host
  envelope fields
- tightening validation so previously valid input is rejected
- changing a documented default in a way that alters behavior
- changing a wire format without a versioned compatibility path

## Behavioral and Validation Changes

Validation tightening and behavior changes are breaking by default when documented
valid input or a documented default changes. A patch release may correct behavior
only when all of these hold:

- the normative specification or existing exported documentation already required
  the new behavior, and the old behavior contradicted it;
- rejected input was outside the documented valid domain, malformed, or unsafe;
- tests or consumer evidence show no documented valid usage depends on the old
  behavior;
- the changelog, compatibility note, and release notes identify the correction
  and any migration step;
- security fixes follow the same evidence rule and document why earlier input was
  not valid under the contract.

If previously documented valid usage must break, provide an opt-in compatibility
path or require a major release. A security exception that cannot preserve that
path must be explicit, approved in the release review, and documented with the
affected behavior and residual risk.

Event ordering, lifecycle callbacks, retry/cancellation semantics, and checkpoint
projection are compatibility-relevant even when exported declarations are
unchanged. They require behavioral tests, a conformance-vector update where the
contract covers them, a release note, and consumer verification for the affected
scope. Do not classify a patch as behavior-free solely because `api/` is
unchanged.

## Deprecation

1. Mark the declaration as deprecated in its doc comment and in
   `CHANGELOG.md`.
2. Keep the old declaration working for at least one minor release.
3. Document the replacement and migration path.
4. Remove it only in the next major release, unless a security issue requires
   faster removal. Security removals must be documented in the release notes.

Deprecated declarations remain covered by the compatibility promise until
removal. Do not silently change their behavior.

## Optional Module Rules

- Tag optional modules as `adapters/<name>/vX.Y.Z`.
- Never move or reuse an existing module tag.
- Declare the minimum compatible core version in the module's `go.mod`.
- Keep provider SDKs out of the core module.
- A module may release independently when its provider or protocol changes.
- Adapter compatibility is tested against the declared core version and the
  published-consumer module.

## Multi-language Core implementations

The `spec/` tree is the normative contract for the Python, TypeScript, and Java
Core implementations. Go remains the reference implementation.

- `spec/SPEC_VERSION` versions the contract independently of Core versions.
- Each Core implementation declares the `SPEC_VERSION` it implements and versions
  independently.
- Wire changes (JSON field names and casing, event types, stream kinds, plugin
  Manifest v1 and envelopes, error codes) are breaking for every Core implementation.
- Behavioral changes require a conformance-vector update and a Core implementation minor
  release.
- While a Core implementation is `0.x`, a breaking source or behavioral change requires a minor
  version and a migration note; a patch must not silently break documented valid
  usage. Wire changes still require `spec/` coordination regardless of Core
  version.
- Source APIs map one-to-one with idiomatic per-language names; parity is
  tracked in `spec/parity.md`.
- A Core implementation may not implement a contract feature that the Go reference lacks.
- A `pkg/...` change that alters documented wire behavior must update `spec/`
  in the same change.

## Release Gates

A release candidate must pass:

- `api/` snapshot and diff review
- root module test, vet, build, race, fuzz, staticcheck, and govulncheck
- independent adapter test, vet, and build
- published-consumer test with no local `replace`
- `spec/` conformance vectors and the parity linter for every shipped Core
- strict docs build
- `CHANGELOG.md`, `VERSION`, compatibility notes, and release notes updated
- SBOM and checksums generated by the release workflow

## How to Review a Change

Ask these questions before merging:

1. Which exported declarations change?
2. Is the change additive, behavioral, or breaking?
3. Is an existing interface method set affected?
4. Does an unkeyed struct literal become invalid?
5. Does a JSON tag, event type, stream kind, or plugin field change?
6. Is a default or validation rule tightened, and was the rejected input valid
   under the previous documented contract?
7. Is the change covered by the API snapshot diff and a consumer test?
8. Is a deprecation period required?
9. Does an optional module need a new tag?
10. What does the release note say the change does not prove?

## Related Documents

- [Compatibility](compatibility.md)
- [API freeze inventory](api-stability.md)
- [Release process](releasing.md)
- [Event schema](../reference/events.md)
- [Plugin authoring](../guides/plugins.md)
- [Plugin trust and SBOM](../security/plugin-trust.md)
