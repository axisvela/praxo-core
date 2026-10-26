# SDK Support Policy

Go is the reference implementation. The normative contract, implementation
scope, source tags, and CI coverage are recorded in the
[language support matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md).

## Implementation Types

| Type | Meaning |
| --- | --- |
| Core | An implementation of the declared core contract, with shared behavior vectors |
| Wire | Serialization and declared wire-level contract surfaces; no native agent loop implied |
| Bridge | A client of the maintained runtime through a process or HTTP boundary |
| Sample | Usage of another SDK, not an independent contract implementation |

Implementation type is not a stability rating or a promise of every Go feature.
C currently exposes a wire-level public API despite its Core matrix classification.
Read each SDK's limitations before adopting it.

## Versions and Distribution

- Core, SDK, adapter, and contract versions are independent.
- Each SDK declares its supported `SPEC_VERSION`.
- A source release tag does not establish package-registry availability.
- Use the installation or source-build instructions on the language page.
- Python and TypeScript document source builds; PyPI and npm publication are pending.
- Java documents a Maven source build; Maven Central publication is not established by a source tag.
- Fortran remains in progress and must not be represented as a released package.

## Feature Boundaries

Python, TypeScript, Java, and C# include streaming and an OpenAI-compatible
adapter. This does not imply those features exist in every other implementation.
Passing shared vectors does not prove complete feature parity with Go, live
provider verification, production readiness, or package publication.

VFS backends, plugin hosts, scheduling, and optional integrations must be
evaluated against the specific SDK's README and API reference.

## Contribution Gates

Core changes require the declared vector groups, parity inventory, API checks,
and language tests. Wire, Bridge, and Sample implementations have narrower gates.
See [language policy](../contributing/language-policy.md) and
[SDK design](../contributing/sdk-design.md). Security-sensitive behavior requires
language-specific tests in addition to shared fixtures.
