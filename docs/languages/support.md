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
C exposes both wire-level JSON primitives and a public Core API.
Read each implementation's current public API and limitations before adopting it.
Bridge and Sample describe how users access a runtime, not proof that their
languages are incapable of Framework support. Shared-runtime languages can
reuse the host Framework rather than duplicate its agent loop.

## Support Levels

Maturity records completion of the declared scope. Support level records who is
expected to respond to issues and security corrections; the two are independent.

| Level | Meaning | Not implied |
| --- | --- | --- |
| `maintained` | Named maintainer or team, CI, and applicable security fixes | Response SLA, full Go parity, every provider |
| `community` | Community maintainers, best-effort updates | Response time, security backport commitment |
| `experimental` | Scope may change; no stability promise | Production use |
| `deprecated` | No new features; migration path documented | Removal date unless stated |

The matrix does not yet publish a support-level column for every row. Until a row
records one, do not infer an official support commitment from `complete`, a
source tag, or package-registry availability. Support levels will be added as
maintainers confirm them.

To record a support level, the responsible maintainer or team should provide the
level, CI job, last verified tag or SHA, and the scope of applicable security
fixes. Do not assign a support level on another person's behalf, and do not treat
a merged implementation PR as a support commitment.

## Versions and Distribution

- The Go core, language Core implementations, adapters, and contract versions are independent.
- Version tags and maturity are separate: a source tag records a release, while
  maturity records declared-scope completion and verification.
- Each Core implementation declares its supported `SPEC_VERSION`.
- A source release tag does not establish package-registry availability.
- Use the installation or source-build instructions on the language page.
- Python publishes `praxo-core==0.2.3` on PyPI. TypeScript publishes
  `@axisvela/praxo-core@0.1.3` on npm from source tag `typescript/v0.1.3`;
  the package was approved on 2026-10-31 and has npm provenance. Current main
  has newer parallel-tool, SSE, and history fixes that are not part of `0.1.3`.
- Java publishes `com.axisvela:praxo-core:0.3.0` on Maven Central from source
  tag `java/v0.3.0`, with Maven groupId `com.axisvela` and Java packages under
  `com.axisvela.praxo`. The earlier `java/v0.2.3` tag retains
  `io.axisvela.praxo`.
- PHP publishes `axisvela/praxo-core==0.1.0` on Packagist from the split
  publication repository `axisvela/praxo-core-php`; source tag `php/v0.1.0`
  remains in this repository.
- Ruby publishes `praxo-core==0.1.0` on RubyGems from source tag
  `ruby/v0.1.0`. A clean project installed the gem and ran a minimal agent.
- Lua publishes `praxo-core==0.1.0-1` on LuaRocks from source tag `lua/v0.1.0`.
  A local rock build and module load passed; registry install smoke is pending.
- C# publishes `Praxo.Core==0.1.2` on NuGet from source tag `csharp/v0.1.2`
  through GitHub Actions Trusted Publishing. CI built, tested, packed, and
  pushed the package; a local .NET consumer install is not yet recorded.
- D publishes `praxo-core==0.1.0` on DUB/code.dlang.org from the split
  repository `axisvela/praxo-core-d` (tag `v0.1.0`); source tag `d/v0.1.0`
  remains in this repository. `dub fetch praxo-core` succeeded.
- Dart has source tag `dart/v0.1.1` and publishes `praxo_core==0.1.1` on
  pub.dev under publisher `axisvela.com`. A clean project installed the package,
  imported `package:praxo_core/praxo_core.dart`, and ran a minimal agent.
- Rust has source tag `rust/v0.1.4` and publishes `praxo-core==0.1.4` on
  crates.io. It includes all eleven vector groups, native tests, `tool.Gateway`,
  `jsonschema.Schema`, and an API snapshot. The OpenAI adapter, VFS, plugin
  hosts, and Go context/cancellation semantics are not included. A clean
  temporary project installed the crate and reported `SDK_VERSION` `0.1.4` and
  `SPEC_VERSION` `0.2.0`.
- Fortran has source tag `fortran/v0.3.0` with all eleven vector groups, native
  tests, an API snapshot, and integrated PII/middleware. It is not a
  package-registry release; asynchronous streaming is outside the declared
  surface, and the bounded JSON Schema subset remains partial.
  Version `0.3.0` replaces the ASCII matcher with RE2/Unicode and requires a
  native C++ library. The historical `0.2.2` tag retains the old matcher without
  that RE2/C++ requirement.
- COBOL has source tag `cobol/v0.1.2` with all eleven vector groups, native and
  contract tests, caller-owned scoped registries, and an API snapshot. It is not a
  package-registry release; most remaining Go surfaces are partial and the
  registry has no concurrency or custom spec provider.
- Haskell has source tag `haskell/v0.2.0` with all eleven vector groups, native
  tests, API snapshot/parity, and runtime/middleware helpers. Hackage publication
  and production readiness are not claimed.
- Delphi/Free Pascal has source tag `delphi/v0.2.1` with all eleven vector groups,
  native tests, and API snapshot/parity under Free Pascal 3.2.2. The commercial
  Delphi compiler, other targets, and package registries are not claimed.
- MATLAB/Octave has source tag `matlab/v0.2.1` with all eleven vector groups,
  native tests, and API snapshot/parity under Octave. The MATLAB runtime,
  provider adapters, and package registries are not claimed.
- OCaml has source tag `ocaml/v0.2.0` with all eleven vector groups, native
  tests, and API snapshot/parity. Native `ocamlopt` compilation, provider
  adapters, and package registries are not claimed.
- Elixir has source tag `elixir/v0.1.1` and publishes `praxo_core==0.1.1` on
  Hex. A clean Mix project installed it, loaded `Praxo.Agent`, and reported
  version `0.1.1`. This is a package-only release; HexDocs are not published.
- Nim, V, and Objective-C have source tags `nim/v0.1.1`, `v/v0.1.1`, and
  `objc/v0.1.1`. They include all eleven vector groups, native tests, and API
  snapshots. Package-registry publication, production readiness, and complete
  Go parity are not claimed; optional Go hooks and provider adapters are not
  included.
- Erlang has source tag `erlang/v0.1.1` and publishes
  `praxo_core_erlang==0.1.1` on Hex; the OTP application name remains
  `praxo_core`. A clean rebar3 project fetched and compiled the package and
  loaded `praxo_agent`. Provider adapters, streaming, and production readiness
  are not claimed; opt-in middleware is integrated, while optional Go hooks are
  not included.
- Lisp has source tag `lisp/v0.1.0` for the SBCL bridge over the bridge CLI. It
  does not provide a native Lisp loop; forwarding, UTF-8, error, and exit-code
  checks pass locally and in Linux CI. Consumer details and package-registry
  publication remain pending.
- Tcl has source tag `tcl/v0.1.0` for the Bridge wrapper over the bridge CLI. It
  does not provide a native Tcl loop; forwarding, UTF-8, error, and exit-code
  tests pass locally and in Linux CI, while package-registry publication remains
  pending.
- Prolog has source tag `prolog/v0.1.1` for the SWI-Prolog bridge over the bridge
  CLI. It does not provide a native Prolog loop; forwarding, UTF-8, error, and
  exit-code tests pass. Package-registry publication and production readiness
  are not claimed.

## Feature Boundaries

Python, TypeScript, Java, and C# include streaming and an OpenAI-compatible
adapter. This does not imply those features exist in every other implementation.
`complete` records declared-scope conformance; the parity inventory may still
contain `partial` or `planned` rows for features outside that scope. Passing
shared vectors does not prove complete feature parity with Go, live
provider verification, production readiness, or package publication.

VFS backends, plugin hosts, scheduling, and optional integrations must be
evaluated against the specific Core's README and API reference.

## Contribution Gates

Core changes require the declared vector groups, parity inventory, API checks,
and language tests. Wire, Bridge, and Sample implementations have narrower gates.
See [language policy](../contributing/language-policy.md) and
[Core design](../contributing/core-design.md). Security-sensitive behavior requires
language-specific tests in addition to shared fixtures.
