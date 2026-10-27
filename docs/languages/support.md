# Language Implementation Support

Go is the reference implementation. The normative contract, implementation
scope, source tags, and CI coverage are recorded in the
[language support matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md).

## Framework Target

The default target for every independently implemented language is a native
Framework implementation of the shared core contract. Wire is an intermediate
stage, not a permanent product category. A language remains wire-only as its
final scope only when documented language or runtime technical limitations
prevent a complete Framework implementation.

An unavailable toolchain, unfinished work, low demand, or an unassigned
maintainer is not evidence that a language cannot support Framework behavior.
Consumer and maintenance gates control when work starts, not the final target.
The target does not imply current availability, a delivery date, every optional
Go integration, or production readiness.

## Current Stages and Delivery Forms

| Type | Meaning |
| --- | --- |
| Framework (`Core`) | Native framework behavior within the declared public scope, with shared behavior vectors |
| Wire | An intermediate implementation of serialization and declared wire surfaces, progressing toward Framework |
| Bridge | A client of the maintained runtime through a process or HTTP boundary |
| Sample | Usage of an existing language implementation, not another independent runtime |

Implementation type is not a stability rating or a promise of every Go feature.
C currently exposes a wire-level public API despite its Core matrix classification.
Read each implementation's current public API and limitations before adopting it.
Bridge and Sample describe how users access a runtime, not proof that their
languages are incapable of Framework support. Shared-runtime languages can
reuse the host Framework rather than duplicate its agent loop.

## Versions and Distribution

- Core, SDK, adapter, and contract versions are independent.
- Version tags and maturity are separate: a source tag records a release, while
  maturity records declared-scope completion and verification.
- Each SDK declares its supported `SPEC_VERSION`.
- A source release tag does not establish package-registry availability.
- Use the installation or source-build instructions on the language page.
- Python and TypeScript document source builds; PyPI and npm publication are pending.
- Java documents a Maven source build; Maven Central publication is not established by a source tag.
- Fortran has source tag `fortran/v0.2.0` with all eleven vector groups, native
  tests, an API snapshot, and integrated PII/middleware. It is not a
  package-registry release; asynchronous stream support and the bounded JSON
  Schema subset remain partial.
- Haskell has source tag `haskell/v0.1.0` and declares three wire groups plus an
  agent loop. It is not a published Hackage package or a production-ready agent
  runtime.
- Delphi/Free Pascal has source tag `delphi/v0.1.0` and remains a Wire-stage
  candidate; the commercial Delphi compiler, remote CI for the loop, and package
  registries are not claimed.
- MATLAB/Octave has source tag `matlab/v0.2.0` with all eleven vector groups,
  native tests, and API snapshot/parity under Octave. The MATLAB runtime,
  provider adapters, and package registries are not claimed.
- OCaml has source tag `ocaml/v0.2.0` with all eleven vector groups, native
  tests, and API snapshot/parity. Native `ocamlopt` compilation, provider
  adapters, and package registries are not claimed.
- Elixir, Nim, V, and Objective-C have source tags `elixir/v0.1.0`,
  `nim/v0.1.0`, `v/v0.1.0`, and `objc/v0.1.0`. They include all eleven vector
  groups, native tests, and API snapshots. Package-registry publication,
  production readiness, and complete Go parity are not claimed; optional Go
  hooks and provider adapters are not included.
- Erlang has source tag `erlang/v0.1.0` with a native BEAM Core loop, eleven
  vector groups, native tests, and an API snapshot/parity inventory. Package
  registries, provider adapters, streaming, and production readiness are not
  claimed; opt-in middleware is integrated, while optional Go hooks are not
  included.
- Lisp has source tag `lisp/v0.1.0` for the SBCL bridge over the bridge CLI. It
  does not provide a native Lisp loop; forwarding, UTF-8, error, and exit-code
  checks pass locally and in Linux CI. Consumer details and package-registry
  publication remain pending.
- Tcl has source tag `tcl/v0.1.0` for the Bridge wrapper over the bridge CLI. It
  does not provide a native Tcl loop; local forwarding, UTF-8, error, and
  exit-code tests pass, while remote CI and package-registry publication remain
  pending.
- Prolog has source tag `prolog/v0.1.1` for the SWI-Prolog bridge over the bridge
  CLI. It does not provide a native Prolog loop; forwarding, UTF-8, error, and
  exit-code tests pass. Package-registry publication and production readiness
  are not claimed.

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
