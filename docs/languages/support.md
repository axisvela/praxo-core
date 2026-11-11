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

The 2026-11-02 source set covers sixteen wired languages: agent-capable Go,
Python, TypeScript, Java, Rust, R, and C# plus the extended C, PHP, Fortran,
COBOL, Ruby, Elixir, Erlang, C++, and Lua implementations. All sixteen wired
languages cover all twenty scenarios. Parallel tools for COBOL, Lua, PHP, and
Fortran are delegated to caller-provided batch callbacks; the Core itself does
not create threads in those cases. See the
[Behavior Lab matrix](behavior-lab-matrix.md) for every cell.

The clean-tree CI run at `b6218e5` reported 320 passed, 0 unsupported, and no
failures for the sixteen-language set. The matrix is generated from that report
and links the same behavior job.

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

### Source, registry, and consumer smoke

These are separate claims. A source tag records a repository release; a registry
version records what a package manager can fetch; a consumer smoke records an
install and run outside the repository. Do not cite one as evidence for another.
Registry values below were checked against the public registries on 2026-11-10.

| Language | Source tag | Registry version | Consumer install smoke |
| --- | --- | --- | --- |
| Python | `python/v0.4.1` | PyPI `praxo-core==0.4.1` published | Release workflow built and smoke-tested `0.4.1`; post-publication consumer check passed locally |
| TypeScript | `typescript/v0.3.0` | npm `@axisvela/praxo-core@0.2.2` published; `0.3.0` source prepared | Release workflow built and consumed the `0.2.2` tarball; `0.3.0` publication pending |
| Java | `java/v0.5.0` | Maven Central `com.axisvela:praxo-core:0.5.0` published with Harmovela and MCP adapters | Central validated and published `0.5.0`; `0.5.0` post-publication consumer check not rerun |
| Rust | `rust/v0.4.0` | crates.io `praxo-core==0.4.0` published; `0.1.4` historical | Recorded for `0.1.4` only; not rerun for `0.4.0` |
| C# | `csharp/v0.4.0` | NuGet `Praxo.Core==0.4.0` published | Not recorded |
| Elixir | `elixir/v0.5.1` | Hex `praxo_core==0.5.1` published with OpenAI-compatible, Harmovela, and MCP adapters; `0.5.0` failed before publication; `0.4.1`, `0.4.0`, `0.3.0`, `0.2.0` historical | Extended starter added; Hex `0.4.1` resolved in a clean Mix project and allow/deny passed locally; `0.5.1` install smoke not rerun |
| Erlang | `erlang/v0.4.0` | Hex `praxo_core_erlang==0.4.0` published; `0.3.1`, `0.2.0` historical | Not rerun for `0.4.0`; historical `0.1.1` smoke |
| Ruby | `ruby/v0.4.1` | RubyGems `praxo-core==0.4.1` published; `0.4.0`, `0.3.0`, `0.2.0` historical | Extended starter added; RubyGems `0.4.1` installed into a clean gem home and allow/deny passed locally |
| Lua | `lua/v0.4.1` | LuaRocks `praxo-core==0.4.1-1` published with the optional OpenAI-compatible adapter; `0.4.0-1`, `0.3.0-1`, `0.2.0-1` also published | Extended starter added; LuaRocks `0.4.1-1` installed into a clean tree and allow/deny passed locally |
| PHP | `php/v0.4.1` | Packagist `axisvela/praxo-core==0.4.1` published with Composer `autoload.files`; `0.4.0`, `0.3.0`, `0.2.0` historical | Extended starter added; Composer install of published `0.4.1` passed locally and the starter passed without a bridge |
| Dart | `dart/v0.1.1` | pub.dev `praxo_core==0.1.1` | Recorded for `0.1.1` |
| Julia | `julia/v0.2.0` | General Registry PR #174826 open via mirror `0.2.0` | Not recorded |
| MATLAB | `matlab/v0.2.1` | MATLAB File Exchange `185166` published | Not recorded |
| Octave | `octave/v0.2.1` | Octave Packages PR #875 open; package archive published | Not recorded |
| Perl | `perl/v0.1.1` | CPAN `Praxo-Core` 0.1.1 uploaded; indexing pending | Not recorded |
| PowerShell | `powershell/v0.2.0` | PowerShell Gallery `praxo-core-ps==0.2.0` published | Not recorded |
| Nim | `nim/v0.1.1` | nim-lang/packages PR #3600 open; nimpkgs re-crawl pending | Not recorded |
| OCaml | `ocaml/v0.3.0` | opam-repository PR #31106 open; package CI passed; opam-ci pending | Not recorded |
| Haskell | `haskell/v0.2.0` | sdist published; API and manual uploads blocked until Hackage trustees add the account to Uploaders | Not recorded |
| Delphi / Free Pascal | `delphi/v0.2.1` | OPM assets published; maintainer submission pending | Not recorded |

### Registry freshness against code

Code manifests are the version source of truth. A registry is current only when
its latest version matches the manifest at the release tag.

| Language | Code/manifest version | Registry latest | Status |
| --- | --- | --- | --- |
| Python | `0.4.1` | PyPI `0.4.1` | current |
| TypeScript | `0.3.0` | npm `0.2.2` | source prepared; registry pending |
| Java | `0.5.0` | Maven Central `0.5.0` | current |
| Rust | `0.4.0` | crates.io `0.4.0` | current |
| C# | `0.4.0` | NuGet `0.4.0` | current |
| Elixir | `0.5.1` | Hex `0.5.1` | current |
| Erlang | `0.4.0` | Hex `0.4.0` | current |
| Ruby | `0.4.1` | RubyGems `0.4.1` | current |
| PHP | `0.4.1` | Packagist `0.4.1` | current |
| Lua | rockspec `0.4.1-1`; source tag `0.4.1` | LuaRocks `0.4.1-1` | current |
| Dart | `0.1.1` | pub.dev `0.1.1` | current |
| Julia | `0.2.0` | General Registry PR #174826 open | pending |
| MATLAB | `0.2.1` | File Exchange `185166` | current |
| Octave | `0.2.1` | Octave Packages PR #875 open | pending |
| Perl | `0.1.1` | CPAN indexing pending | pending |
| PowerShell | `0.2.0` | PowerShell Gallery `0.2.0` | current |

Do not install a source-tag-only language from a registry, and do not assume a
registry package contains the source tag's latest behavior. The language page is
the installation source of truth.

- Python publishes `praxo-core==0.3.2` on PyPI from source tag
  `python/v0.3.2`. TypeScript publishes `@axisvela/praxo-core@0.2.2` on npm from
  source tag `typescript/v0.2.2`; the package has npm provenance and an
  agent-framework-first README and metadata.
- Java source tag `java/v0.5.0` adds the Harmovela sink and stdio MCP client
  under `com.axisvela.praxo.adapters` with Maven groupId `com.axisvela` and
  Java packages under `com.axisvela.praxo`. Maven Central publishes
  `com.axisvela:praxo-core:0.5.0`. The earlier `java/v0.2.3` tag retains
  `io.axisvela.praxo`.
- PHP source tag `php/v0.4.0` adds HITL interrupt decisions to streaming runs,
  cancellation, SSE validation, final authorization, lifecycle cleanup, and
  caller-provided cooperative parallel tool dispatch through `batchToolInvoker`.
  Packagist publishes `axisvela/praxo-core==0.4.0` from the split repository
  `axisvela/praxo-core-php`; `v0.3.0` and `v0.2.0` remain available. The Core
  does not create threads. A Composer install smoke is not yet recorded.
- Ruby source tag `ruby/v0.4.0` adds HITL interrupt decisions to middleware
  hooks, final-tool allowlist checks, reauthorization, lifecycle cleanup,
  cancellation, stream callbacks, a native SSE parser, bounded parallel tools,
  and run-scoped call limits. RubyGems publishes `praxo-core==0.4.0`;
  `0.3.0` and `0.2.0` remain available. The recorded clean-project smoke covers
  only `0.1.0`.
- C++ source tag `cpp/v0.4.0` adds HITL interrupt decisions to middleware hooks,
  final-tool allowlist checks, reauthorization, lifecycle cleanup, cancellation,
  stream callbacks, a native SSE parser, bounded parallel tools, and run-scoped
  call limits.
- Lua source tag `lua/v0.4.0` adds HITL interrupt decisions to middleware hooks,
  final-tool allowlist checks, reauthorization, lifecycle cleanup, cancellation,
  stream callbacks, a native SSE parser, and caller-provided batch tool dispatch.
  Rock revision `0.4.0-1` is built and published by
  `.github/workflows/lua-release.yml`; LuaRocks also retains `0.3.0-1` and
  `0.2.0-1`. The workflow installs the generated source rock in a clean tree and
  runs the installed smoke; registry install smoke is not yet recorded.
- C# source tag `csharp/v0.4.0` adds the OpenAI-compatible model adapter,
  Harmovela sink, and stdio MCP client under `Adapters/` to streaming runs,
  cancellation, bounded parallel tools, SSE validation, and HITL interrupt
  decisions. NuGet publishes `Praxo.Core==0.4.0`; a local .NET consumer install
  is not yet recorded.
- D publishes `praxo-core==0.1.0` on DUB/code.dlang.org from the split
  repository `axisvela/praxo-core-d` (tag `v0.1.0`); source tag `d/v0.1.0`
  remains in this repository. `dub fetch praxo-core` succeeded.
- Dart has source tag `dart/v0.1.1` and publishes `praxo_core==0.1.1` on
  pub.dev under publisher `axisvela.com`. A clean project installed the package,
  imported `package:praxo_core/praxo_core.dart`, and ran a minimal agent.
- Rust source tag `rust/v0.4.0` adds provider-neutral model types and the
  OpenAI-compatible, Harmovela, and MCP adapters under `adapters::` to all
  eleven vector groups, native tests, `tool.Gateway`, `jsonschema.Schema`,
  streaming callbacks, cancellation, bounded parallel tools, HITL interrupt
  decisions, and an API snapshot. crates.io publishes `praxo-core==0.4.0`; the
  recorded clean temporary-project install smoke covers `0.1.4` and reported
  `SDK_VERSION` `0.1.4` and `SPEC_VERSION` `0.2.0`. VFS and plugin hosts are not
  included.
- R source tag `r/v0.6.1` adds the OpenAI-compatible adapter, Harmovela sink,
  and stdio MCP client to policy, middleware, lifecycle cleanup, cancellation,
  streaming callbacks, an SSE parser, bounded parallel tools, HITL interrupt
  decisions, and an API snapshot. Unix uses `mclapply`; Windows uses a PSOCK
  cluster. r-universe publishes `praxocore==0.6.1` from `language/r`; CRAN
  publication is not claimed. The release workflow runs `R CMD build` and
  `R CMD check`.
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
  tests, API snapshot/parity, and runtime/middleware helpers. Hackage
  publication is prepared by `.github/workflows/haskell-release.yml`; the 0.2.0
  sdist is published on the `haskell/v0.2.0` GitHub release. Both API and
  manual candidate uploads return an unauthorized-uploader error until the
  Hackage trustees add the account to the Uploaders group. Production
  readiness is not claimed.
- Delphi/Free Pascal has source tag `delphi/v0.2.1` with all eleven vector groups,
  native tests, and API snapshot/parity under Free Pascal 3.2.2. OPM assets
  are published on the `delphi/v0.2.1` GitHub release; maintainer submission
  is pending. The commercial Delphi compiler and other targets are not
  claimed.
- MATLAB has source tag `matlab/v0.2.1` with all eleven vector groups, native
  tests, and API snapshot/parity. MATLAB and Octave share
  `language/matlab-octave-core/+praxo`. MATLAB File Exchange `185166` is
  published; the MATLAB runtime and provider adapters are not claimed.
- Octave has source tag `octave/v0.2.1` with all eleven vector groups, native
  tests, and API snapshot/parity under GNU Octave 11.3.0. It shares
  `language/matlab-octave-core/+praxo` with MATLAB. The package archive is
  published on the `octave/v0.2.1` GitHub release and Octave Packages PR #875
  is open.
- OCaml has source tag `ocaml/v0.3.0` with all eleven vector groups, native
  tests, and API snapshot/parity. The split package repository
  `axisvela/praxo-core-ocaml` publishes opam package `praxo-core` 0.3.0 with module `Praxo_core`;
  opam-repository PR #31106 is open. Native `ocamlopt` compilation and
  provider adapters are not claimed.
- Elixir source tag `elixir/v0.5.1` adds the Harmovela sink and stdio MCP client
  under `adapters/` to policy hooks, middleware, final-tool allowlist checks,
  reauthorization, lifecycle cleanup, cancellation, stream callbacks, a native
  SSE parser, bounded parallel tools, HITL interrupt decisions, and run-scoped
  call limits. Hex publishes `praxo_core==0.5.1`; `0.4.1`, `0.4.0`, `0.3.0`,
  and `0.2.0` remain available. HexDocs are published at
  <https://praxo-core.hexdocs.pm/0.5.1/>.
- Nim, V, and Objective-C have source tags `nim/v0.1.1`, `v/v0.1.2`, and
  `objc/v0.1.1`. They include all eleven vector groups, native tests, and API
  snapshots. Nim publishes the Nimble package `praxo_core` from
  `axisvela/praxo-core-nim` with root `praxo_core.nimble` version `0.1.1`;
  nim-lang/packages PR #3600 is pending and nimpkgs still marks the old
  monorepo entry broken until its next crawl. A registry install smoke is not
  yet recorded. V
  and Objective-C have `v.mod` and CocoaPods metadata respectively, but their
  registry split-repository steps are still pending. V publishes package
  `praxo-core` tag `0.1.2` from `axisvela/praxo-core-v`; VPM submission is
  pending. Swift
  publishes SPM tag `0.2.0` from `axisvela/praxo-core-swift`; Swift Package
  Index PR #16032 is open. Production readiness and complete Go parity are not
  claimed; optional Go hooks and provider adapters are not included.
- Erlang source tag `erlang/v0.4.0` adds HITL interrupt decisions to policy
  hooks, middleware, final-tool allowlist checks, reauthorization, lifecycle
  cleanup, cancellation, stream callbacks, a native SSE parser, bounded parallel
  tools, and run-scoped call limits. Hex publishes
  `praxo_core_erlang==0.4.0`; `0.3.1` and `0.2.0` remain available. Provider adapters, HTTP streaming, and production readiness are not
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
