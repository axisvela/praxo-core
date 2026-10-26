# Language Implementation Policy

This page defines public contribution requirements, not a schedule or a promise
to implement additional languages. Current scope is recorded in the
[language matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md).

## Choose the Smallest Appropriate Implementation

- Core implements the declared native contract and agent behavior.
- Wire implements only its declared serialization and wire surfaces.
- Bridge delegates execution through the [bridge contract](https://github.com/axisvela/praxo-core/blob/main/spec/bridge.md).
- Sample reuses an existing runtime package.

JavaScript reuses TypeScript; Kotlin and Scala reuse Java; Visual Basic reuses
.NET. Do not create another agent loop for the same runtime without a concrete
consumer need and a maintenance owner.

## Required Evidence

| Type | Required checks |
| --- | --- |
| Core | All declared core vector groups, parity inventory, API snapshot, build and language tests |
| Wire | Declared wire/subset vectors, serialization and error-code tests |
| Bridge | Framing, exit codes, errors, and bridge contract tests |
| Sample | Build or execute against the host package |

New native loops require a named consumer and a maintenance owner. Shared vectors
do not replace tests for cancellation, concurrency, path containment, or other
security-sensitive behavior.

## Public Documentation

Every delivered implementation needs a language entry page, a source README,
installation or build instructions, supported contract version, limitations, and
test commands. Distinguish source tags from registry publication. Update the
matrix and parity inventory with changes to the declared scope.

All SDKs remain MIT. Dependencies require compatible licenses; provider
credentials, tenant data, and product-only behavior do not belong in the SDK.
