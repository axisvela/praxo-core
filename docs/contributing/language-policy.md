# Language Implementation Policy

This page defines public contribution requirements, not a schedule or a promise
to implement additional languages. Current scope is recorded in the
[language matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md).

## Target Framework, Declare the Current Stage

- Framework is the default target for independently implemented languages that
  can support the shared core contract. `Core` remains the existing scope identifier.
- Wire is an intermediate stage toward Framework. It currently implements only
  its declared serialization and wire surfaces; it must not be advertised as a
  complete Framework before the public API and behavior are implemented and verified.
- Bridge delegates execution through the [bridge contract](https://github.com/axisvela/praxo-core/blob/main/spec/bridge.md).
- Sample reuses an existing runtime package.

Wire-only is a final scope only when documented language or runtime technical
limitations prevent a complete Framework implementation. Record the specific
unsupported requirements and the evidence; do not infer inability from a
missing toolchain, incomplete work, low demand, or lack of a maintainer.
An exception must be explicit in the language's support documentation and matrix.

The default target is not a release promise or permission to skip consumer,
maintenance, conformance, security, or licensing gates. Current stage, final
target, feature coverage, verification, and distribution are separate facts.

JavaScript reuses TypeScript; Kotlin, Scala, Groovy, and Clojure reuse Java;
Visual Basic and F# reuse .NET; the OpenCL sample reuses the C SDK. Do not
create another agent loop for the same runtime without a concrete consumer need
and a maintenance owner.

## Required Evidence

| Type | Required checks |
| --- | --- |
| Core | All declared core vector groups, parity inventory, API snapshot, build and language tests |
| Wire | Declared wire/subset vectors, serialization and error-code tests |
| Bridge | Framing, exit codes, errors, and bridge contract tests |
| Sample | Build or execute against the host package |

New native loops require a named consumer and a maintenance owner. This controls
implementation sequencing, not whether Framework is the final target. Shared vectors
do not replace tests for cancellation, concurrency, path containment, or other
security-sensitive behavior.

## Public Documentation

Every delivered implementation needs a language entry page, a source README,
installation or build instructions, supported contract version, limitations, and
test commands. Distinguish source tags from registry publication. Update the
matrix and parity inventory with changes to the declared scope.
Wire entries state Framework as their target unless a documented technical
exception applies. Do not change the current scope to Core merely because that
is the target, or because a conformance runner passes core vectors.

All SDKs remain MIT. Dependencies require compatible licenses; provider
credentials, tenant data, and product-only behavior do not belong in the SDK.
