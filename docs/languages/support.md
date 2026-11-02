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

## Behavior Capability Tiers

Contract tier and behavior tier answer different questions. A language can be
contract `Core` while its agent behavior is still partial, or remain outside the
Behavior Lab entirely.

| Behavior tier | Languages | Current target |
| --- | --- | --- |
| Agent-capable | Go, Python, TypeScript, Java, Rust, R, C# | Native agent loop in declared scope; selected for the twenty Behavior Lab scenarios |
| Extended | C, PHP, Fortran, COBOL, Ruby, Elixir, Erlang, C++, Lua | Contract or focused implementation; behavior coverage advances scenario by scenario with a named consumer and maintainer |
| Optional | Other declared implementations | Outside the current Behavior Lab program; contract conformance is unchanged and behavior work requires a named consumer and maintainer |

The 2026-11-01 source set covers sixteen wired languages: agent-capable Go,
Python, TypeScript, Java, Rust, R, and C# plus the extended C, PHP, Fortran,
COBOL, Ruby, Elixir, Erlang, C++, and Lua implementations. All sixteen wired
languages cover all twenty scenarios. Parallel tools for COBOL, Lua, PHP, and
Fortran are delegated to caller-provided batch callbacks; the Core itself does
not create threads in those cases. See the
[Behavior Lab matrix](behavior-lab-matrix.md) for every cell.

The clean-tree local run at `4ffd83b` reported 320 passed, 0 unsupported, and
no failures for the sixteen-language set. The matrix is generated from that
report; CI re-pinning for this revision is still required.

An unsupported cell is a recorded gap, not a failure and not a pass. Do not
infer full behavior parity from `complete` contract maturity.

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
- Python publishes `praxo-core==0.3.0` on PyPI from source tag
  `python/v0.3.0`. TypeScript stages `@axisvela/praxo-core@0.2.0` on npm from
  source tag `typescript/v0.2.0`; the package has npm provenance and an
  agent-framework-first README and metadata.
- Java source tag `java/v0.4.0` adds HITL interrupt decisions with Maven groupId
  `com.axisvela` and Java packages under `com.axisvela.praxo`. Maven Central
  remains `com.axisvela:praxo-core:0.3.0` until `0.4.0` is published. The
  earlier `java/v0.2.3` tag retains `io.axisvela.praxo`.
- PHP source tag `php/v0.4.0` adds HITL interrupt decisions to streaming runs,
  cancellation, SSE validation, final authorization, lifecycle cleanup, and
  caller-provided cooperative parallel tool dispatch through `batchToolInvoker`.
  The Packagist
  package remains `axisvela/praxo-core==0.1.0` from the split publication
  repository `axisvela/praxo-core-php`; the Core does not create threads.
- Ruby source tag `ruby/v0.4.0` adds HITL interrupt decisions to middleware
  hooks, final-tool allowlist checks, reauthorization, lifecycle cleanup,
  cancellation, stream callbacks, a native SSE parser, bounded parallel tools,
  and run-scoped call limits. The
  RubyGems package remains `praxo-core==0.1.0`; a clean project installed it and
  ran a minimal agent.
- C++ source tag `cpp/v0.4.0` adds HITL interrupt decisions to middleware hooks,
  final-tool allowlist checks, reauthorization, lifecycle cleanup, cancellation,
  stream callbacks, a native SSE parser, bounded parallel tools, and run-scoped
  call limits.
- Lua source tag `lua/v0.4.0` adds HITL interrupt decisions to middleware hooks,
  final-tool allowlist checks, reauthorization, lifecycle cleanup, cancellation,
  stream callbacks, a native SSE parser, and caller-provided batch tool dispatch.
  The LuaRocks
  package remains `praxo-core==0.1.0-1`. A local rock build and module load
  passed; registry install smoke is pending.
- C# source tag `csharp/v0.3.0` adds HITL interrupt decisions to streaming
  runs, cancellation, bounded parallel tools, and SSE validation. The tag
  workflow published `Praxo.Core==0.3.0` on NuGet; a local .NET consumer
  install is not yet recorded.
- D publishes `praxo-core==0.1.0` on DUB/code.dlang.org from the split
  repository `axisvela/praxo-core-d` (tag `v0.1.0`); source tag `d/v0.1.0`
  remains in this repository. `dub fetch praxo-core` succeeded.
- Dart has source tag `dart/v0.1.1` and publishes `praxo_core==0.1.1` on
  pub.dev under publisher `axisvela.com`. A clean project installed the package,
  imported `package:praxo_core/praxo_core.dart`, and ran a minimal agent.
- Rust source tag `rust/v0.3.0` adds HITL interrupt decisions to all eleven
  vector groups, native tests, `tool.Gateway`, `jsonschema.Schema`, streaming
  callbacks, cancellation, bounded parallel tools, and an API snapshot. The
  crates.io package remains
  `praxo-core==0.1.4`; a clean temporary project installed that package and
  reported `SDK_VERSION` `0.1.4` and `SPEC_VERSION` `0.2.0`. The HTTP OpenAI
  adapter, VFS, and plugin hosts are not included.
- R source tag `r/v0.5.0` adds HITL interrupt decisions to policy, middleware,
  lifecycle cleanup, cancellation, streaming callbacks, an SSE parser, bounded
  parallel tools, and an API snapshot. Unix uses `mclapply`; Windows uses a PSOCK cluster. No
  package-registry release is claimed.
- C source tag `c/v0.6.0` adds human-in-the-loop interrupt decisions on top of
  policy authorization, ordered middleware, lifecycle cleanup, final-tool
  allowlist checks, middleware reauthorization, cancellation, streaming
  callbacks, an SSE parser, and bounded parallel tools. Unix uses pthread
  workers with per-thread arenas; Windows keeps the sequential path.
- Fortran source tag `fortran/v0.6.0` adds HITL interrupt decisions to all
  eleven vector groups, native tests, an API snapshot, PII/middleware,
  policy-backed middleware/lifecycle authorization, cancellation, stream
  callbacks, a native SSE parser, and caller-provided batch tool dispatch. HITL
  runs use the sequential tool path. It is not a package-registry release;
  asynchronous provider streaming is outside the declared surface, and the
  bounded JSON Schema subset remains partial. Version `0.3.0` replaced the ASCII matcher with RE2/Unicode and
  requires a native C++ library; the historical `0.2.2` tag retains the old
  matcher without that RE2/C++ requirement.
- COBOL has source tag `cobol/v0.4.0` with all eleven vector groups, HITL
  interrupt decisions, native and contract tests, caller-owned scoped
  registries, and an API snapshot. It adds middleware, lifecycle, cancellation,
  streaming, SSE, and caller-provided batch tool dispatch, reaching 20/20
  behavior scenarios. Parallel tools are
  delegated to the batch dispatcher rather than native threads. It is not a
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
- Elixir source tag `elixir/v0.4.0` adds HITL interrupt decisions to policy
  hooks, middleware, final-tool allowlist checks, reauthorization, lifecycle
  cleanup, cancellation, stream callbacks, a native SSE parser, bounded parallel
  tools, and run-scoped call limits. The Hex package remains
  `praxo_core==0.3.0`; `0.2.0` is also published.
  HexDocs are not published.
- Nim, V, and Objective-C have source tags `nim/v0.1.1`, `v/v0.1.1`, and
  `objc/v0.1.1`. They include all eleven vector groups, native tests, and API
  snapshots. Package-registry publication, production readiness, and complete
  Go parity are not claimed; optional Go hooks and provider adapters are not
  included.
- Erlang source tag `erlang/v0.4.0` adds HITL interrupt decisions to policy
  hooks, middleware, final-tool allowlist checks, reauthorization, lifecycle
  cleanup, cancellation, stream callbacks, a native SSE parser, bounded parallel
  tools, and run-scoped call limits. The Hex package remains
  `praxo_core_erlang==0.3.1`; `0.2.0` is also
  published. Provider adapters, HTTP streaming, and production readiness are not
  claimed.
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

Python, TypeScript, Java, Rust, R, and C# include human-in-the-loop interrupt
decisions. Python, TypeScript, Java, and C# also include streaming and an
OpenAI-compatible adapter. This does not imply those features exist in every
other implementation.
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
