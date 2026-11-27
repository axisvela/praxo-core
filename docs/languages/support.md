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
reuse the host Framework rather than duplicate its agent loop. Sample-only
implementations such as Kotlin, VB.NET, and Scala remain in the monorepo as
examples over their host Core; they do not need an independent repository or
package unless promoted to a separately versioned Core.

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
Public audit: 2026-11-26. Versioned evidence URLs are in
[Registry Publication Status](registry-status.md); known immutable README/POM
defects are in the [page audit](registry-pages.md). Publication is not page
acceptance, and no new consumer smoke or remote correction is claimed here.

| Language | Source tag | Registry version | Consumer install smoke |
| --- | --- | --- | --- |
| Go | `v2.11.0` | Go proxy `v2.11.0` published | Release docs dated Nov 26; proxy published Nov 25 UTC; no new consumer smoke recorded |
| Python | `python/v0.11.0` | PyPI `praxo-core==0.11.0` published | Historical docs CI upgrade to `0.10.0` passed; `0.11.0` consumer smoke not recorded |
| TypeScript | `typescript/v0.10.0` | npm `@axisvela/praxo-core@0.10.0` published as `latest` | Historical docs CI upgrade to `0.9.0` passed; `0.10.0` consumer smoke not recorded |
| Java | `java/v0.12.0` | Maven Central `com.axisvela:praxo-core:0.12.0` published | Historical `0.11.0` docs CI install passed on 2026-11-20 (run `44731906136`); `0.12.0` consumer smoke not recorded |
| Rust | `rust/v0.11.1` | crates.io `praxo-core==0.11.0` published | 0.11.1 publication pending; registry consumer install not rerun |
| C# | `csharp/v0.11.0` | NuGet `Praxo.Core==0.11.0` published | Published-package install for `0.9.1` is historical; `0.11.0` smoke not recorded |
| Elixir | `elixir/v0.11.0` | Hex `praxo_core==0.11.0` published | Earlier clean Mix install covered `0.4.1`; `0.11.0` smoke not recorded |
| Erlang | `erlang/v0.10.0` | Hex `praxo_core_erlang==0.10.0` published | Historical `0.1.1` smoke; `0.10.0` smoke not recorded |
| Ruby | `ruby/v0.10.0` | RubyGems `praxo-core==0.10.0` published | Historical CI allow/deny passed for `0.9.2` on 2026-11-21 (run `44913820352`); `0.10.0` smoke not recorded |
| Lua | `lua/v0.9.1` | LuaRocks `praxo-core==0.9.1-1` published | `0.9.1-1` adds the README-synced rockspec description; `0.9.0-1` smoke not recorded |
| PHP | `php/v0.10.0` | Packagist `axisvela/praxo-core==0.10.0` published | Historical Composer allow/deny passed for `0.8.1` on 2026-11-18; `0.10.0` smoke not recorded |
| Dart | `dart/v0.8.0` | pub.dev `praxo_core==0.8.0` published | Prior clean `0.6.1` smoke passed; `0.8.0` smoke not recorded |
| D | `d/v0.8.0` | DUB `praxo-core==0.8.0` published | Consumer smoke not recorded for `0.8.0` |
| Swift | `swift/v0.9.0` | SPI split package `0.7.2` indexed; split repository tagged `0.9.0` with streaming scope; SPI re-index pending | Local Windows full test blocked; typecheck passed; consumer smoke not recorded |
| Julia | `julia/v0.9.0` | General Registry PR #176393 updated to 0.9.0; merge pending | Not recorded |
| MATLAB | `matlab/v0.9.0` | MATLAB File Exchange `185166` published (`0.9.1`) | Citation still `0.2.1`; broad compatibility and native MATLAB execution unverified |
| Octave | `octave/v0.9.0` | Octave `0.9.0` release tarball published; Octave Packages PR #875 pending | Not recorded; Octave 11.3.0 local execution only |
| R | `r/v0.12.0` | r-universe `praxocore==0.12.0` published; CRAN not published | Actual build HEAD `9b417e3`; checks include warnings, not all clean. Post-publication consumer install not recorded; CRAN requires `R CMD check --as-cran` |
| Perl | `perl/v0.8.0` | CPAN `Praxo-Core==0.8.0` published | Consumer install not recorded for `0.8.0` |
| PowerShell | `powershell/v0.9.1` | PowerShell Gallery `praxo-core-ps==0.9.1` published | Release workflow run `45922472866` published 0.9.1 with example, tutorial, and reference-application lists in the Gallery description |
| Nim | `nim/v0.8.0` | Split repository `v0.8.0` tagged; nim-lang/packages PR #3600 merged; nimpkgs re-crawl pending | Not recorded |
| OCaml | `ocaml/v0.11.1` | Not published to opam; replacement submission pending | Split source aligned to `0.11.1`; native-fixture package suite validated locally; registry acceptance pending |
| Haskell | `haskell/v0.9.0` | Hackage `praxo-core==0.9.0` published | Consumer install not recorded for `0.9.0` |
| Delphi / Free Pascal | `delphi/v0.9.0` | OPM `0.9.0`; 0.9.0 OPM assets published; OPM listing pending | Not recorded; commercial Delphi unverified |

### Registry freshness against code

Code manifests are the version source of truth. A registry is current only when
its latest version matches the manifest at the release tag.

| Language | Code/manifest version | Registry latest | Status |
| --- | --- | --- | --- |
| Go | 2.11.0 | Go proxy `v2.11.0` | version matches; README stale |
| Python | 0.11.0 | PyPI `0.11.0` | version matches; README stale |
| TypeScript | 0.10.0 | npm `0.10.0` | version matches; README stale |
| Java | 0.12.0 | Maven Central `0.12.0` | version matches; POM SCM stale |
| Rust | 0.11.1 | crates.io `0.11.0` | 0.11.1 publication pending; README updated |
| C# | 0.11.0 | NuGet `0.11.0` | version matches; README stale |
| Elixir | 0.11.0 | Hex `0.11.0` | version matches |
| Erlang | 0.10.0 | Hex `0.10.0` | version matches |
| Ruby | 0.10.0 | RubyGems `0.10.0` | version matches |
| PHP | 0.10.0 | Packagist `0.10.0` | version matches |
| Lua | 0.9.1-1 | LuaRocks `0.9.1-1` | version matches |
| Dart | 0.8.0 | pub.dev `0.8.0` | version matches; README stale |
| Julia | 0.9.0 | General Registry PR #176393 updated; merge pending | PR targets 0.9.0; pending |
| MATLAB | 0.9.0 | File Exchange `185166` (`0.9.1`) | different source/registry versions; citation stale; MATLAB unverified |
| Octave | 0.9.0 | 0.9.0 release tarball; Octave Packages PR #875 pending | archive available; index pending |
| Perl | 0.8.0 | CPAN `0.8.0` | version matches |
| PowerShell | 0.9.1 | PowerShell Gallery `0.9.1` | version matches |
| Haskell | 0.9.0 | Hackage `0.9.0` | version matches; README stale |
| R | 0.12.0 | r-universe `0.12.0` | version matches; check warnings; CRAN not published |
| Nim | 0.8.0 | split source tagged; registry index pending | split repository `v0.8.0` tagged; Nimble/nimpkgs re-crawl pending |
| OCaml | 0.11.1 | not published to opam; replacement submission pending | split source aligned and native-fixture package validated |
| Swift | 0.9.0 | SPI `0.7.2` | split repository `0.9.0` tagged; SPI re-index pending |
| V | 0.8.0 | split repository `0.8.0` tagged | VPM submission pending; not accepted |
| Delphi / Free Pascal | 0.9.0 | GitHub release assets `0.9.0` | OPM listing unverified |
| D | 0.8.0 | DUB `0.8.0` | version matches |

Do not install a source-tag-only language from a registry, and do not assume a
registry package contains the source tag's latest behavior. The language page is
the installation source of truth.

The release notes below are historical capability context, not a current
installation index. Use the tables above and
[Registry Publication Status](registry-status.md) for current versions.

- Python publishes `praxo-core==0.5.0` on PyPI from source tag
  `python/v0.5.0`. TypeScript publishes `@axisvela/praxo-core@0.4.1` on npm from
  source tag `typescript/v0.4.1`; the package has npm provenance and an
  agent-framework-first README and metadata.
- Java source tag `java/v0.7.0` adds MCP Streamable HTTP support to the stdio
  client and the Harmovela sink under `com.axisvela.praxo.adapters` with Maven
  groupId `com.axisvela` and Java packages under `com.axisvela.praxo`. Maven
  Central publishes `com.axisvela:praxo-core:0.6.0`. The earlier `java/v0.2.3`
  tag retains `io.axisvela.praxo`.
- PHP source tag `php/v0.4.0` adds HITL interrupt decisions to streaming runs,
  cancellation, SSE validation, final authorization, lifecycle cleanup, and
  caller-provided cooperative parallel tool dispatch through `batchToolInvoker`.
  Packagist publishes `axisvela/praxo-core==0.4.1` from the split repository
  `axisvela/praxo-core-php`; `v0.4.0`, `v0.3.0`, and `v0.2.0` remain available. The Core
  does not create threads. A Composer install smoke is not yet recorded.
- Ruby source tag `ruby/v0.4.0` adds HITL interrupt decisions to middleware
  hooks, final-tool allowlist checks, reauthorization, lifecycle cleanup,
  cancellation, stream callbacks, a native SSE parser, bounded parallel tools,
  and run-scoped call limits. RubyGems publishes `praxo-core==0.5.0`;
  `0.4.1`, `0.4.0`, `0.3.0`, and `0.2.0` remain available. The recorded
  clean-project smoke covers `0.4.1`.
- C++ source tag `cpp/v0.5.0` adds HITL interrupt decisions to middleware hooks,
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
- C# source tag `csharp/v0.5.0` adds the OpenAI-compatible model adapter,
  Harmovela sink, and stdio MCP client under `Adapters/` to streaming runs,
  cancellation, bounded parallel tools, SSE validation, and HITL interrupt
  decisions. NuGet publishes `Praxo.Core==0.5.0`; a local .NET consumer install
  is not yet recorded.
- D publishes `praxo-core==0.1.0` on DUB/code.dlang.org from the split
  repository `axisvela/praxo-core-d` (tag `v0.1.0`); source tag `d/v0.2.0`
  remains in this repository. `dub fetch praxo-core` succeeded.
- Dart has source tag `dart/v0.2.0` and publishes `praxo_core==0.2.0` on
  pub.dev under publisher `axisvela.com`. A clean project installed `0.1.1`,
  imported `package:praxo_core/praxo_core.dart`, and ran a minimal agent.
- Rust source tag `rust/v0.5.0` adds provider-neutral model types and the
  OpenAI-compatible, Harmovela, and MCP adapters under `adapters::` to all
  eleven vector groups, native tests, `tool.Gateway`, `jsonschema.Schema`,
  streaming callbacks, cancellation, bounded parallel tools, HITL interrupt
  decisions, and an API snapshot. crates.io publishes `praxo-core==0.5.0`; the
  recorded clean temporary-project install smoke covers `0.1.4` and reported
  `SDK_VERSION` `0.1.4` and `SPEC_VERSION` `0.2.0`. VFS and plugin hosts are not
  included.
- R source tag `r/v0.7.1` adds the OpenAI-compatible adapter, Harmovela sink,
  and stdio MCP client to policy, middleware, lifecycle cleanup, cancellation,
  streaming callbacks, an SSE parser, bounded parallel tools, HITL interrupt
  decisions, and an API snapshot. Unix uses `mclapply`; Windows uses a PSOCK
  cluster. r-universe publishes `praxocore==0.7.1` from `language/r`; CRAN
  publication is not claimed. The release workflow runs `R CMD build` and
  `R CMD check`.
- C source tag `c/v0.7.0` adds human-in-the-loop interrupt decisions on top of
  policy authorization, ordered middleware, lifecycle cleanup, final-tool
  allowlist checks, middleware reauthorization, cancellation, streaming
  callbacks, an SSE parser, and bounded parallel tools. Unix uses pthread
  workers with per-thread arenas; Windows keeps the sequential path.
- Fortran source tag `fortran/v0.7.0` adds HITL interrupt decisions to all
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
- Haskell has source tag `haskell/v0.3.0` with all eleven vector groups, native
  tests, API snapshot/parity, and runtime/middleware helpers. Hackage publishes
  `praxo-core==0.3.0`; the release workflow is
  `.github/workflows/haskell-release.yml`. Production readiness is not claimed.
- Delphi/Free Pascal has source tag `delphi/v0.3.0` with all eleven vector groups,
  native tests, and API snapshot/parity under Free Pascal 3.2.2. OPM assets
  are published on the `delphi/v0.3.0` GitHub release; maintainer submission
  is pending. The commercial Delphi compiler and other targets are not
  claimed.
- MATLAB has source tag `matlab/v0.3.0` with all eleven vector groups, native
  tests, and API snapshot/parity. MATLAB and Octave share
  `language/matlab-octave-core/+praxo`. MATLAB File Exchange `185166` (`0.3.0`)
  is published; MATLAB runtime compatibility and live-provider behavior are not
  claimed.
- Octave has source tag `octave/v0.3.0` with all eleven vector groups, native
  tests, and API snapshot/parity under GNU Octave 11.3.0. It shares
  `language/matlab-octave-core/+praxo` with MATLAB. The package archive is
  published on the `octave/v0.3.0` GitHub release and Octave Packages PR #875
  is open.
- OCaml has source tag `ocaml/v0.4.0` with all eleven vector groups, native
  tests, and API snapshot/parity. The split package repository
   `axisvela/praxo-core-ocaml` prepared package `praxo-core` 0.3.0 with module `Praxo_core`;
   this is not opam registry publication. PR #31222 closed. Native `ocamlopt` compilation and
  live-provider behavior are not claimed.
- Elixir source tag `elixir/v0.6.0` adds the Harmovela sink and stdio MCP client
  under `adapters/` to policy hooks, middleware, final-tool allowlist checks,
  reauthorization, lifecycle cleanup, cancellation, stream callbacks, a native
  SSE parser, bounded parallel tools, HITL interrupt decisions, and run-scoped
  call limits. Hex publishes `praxo_core==0.6.0`; `0.5.1`, `0.4.1`, `0.4.0`,
  `0.3.0`, and `0.2.0` remain available. HexDocs are published at
  <https://praxo-core.hexdocs.pm/0.6.0/>.
- Nim, V, and Objective-C have source tags `nim/v0.8.0`, `v/v0.8.0`, and
  `objc/v0.8.0`. They include all eleven vector groups, native tests, and API
  snapshots. Nim publishes package `praxo_core` from
  `axisvela/praxo-core-nim`; the split repository is tagged `v0.8.0`, and
  nim-lang/packages points at it. A registry install smoke is not yet recorded.
  V publishes package `praxo-core` from `axisvela/praxo-core-v`; the split
  repository is tagged `0.8.0`, while VPM submission is pending and registry
  availability remains unverified. Objective-C remains source-only. Swift
   publishes SPM tag `0.9.0` from `axisvela/praxo-core-swift`; Swift Package
   Index `0.7.2` remains indexed while `0.9.0` re-indexing is pending. Production readiness and complete Go parity are not
  claimed; optional Go hooks and provider adapters are not included.
- Erlang source tag `erlang/v0.5.0` adds HITL interrupt decisions to policy
  hooks, middleware, final-tool allowlist checks, reauthorization, lifecycle
  cleanup, cancellation, stream callbacks, a native SSE parser, bounded parallel
  tools, and run-scoped call limits. Hex publishes
  `praxo_core_erlang==0.5.0`; `0.4.0`, `0.3.1`, and `0.2.0` remain available.
  Live-provider behavior, HTTP streaming, and production readiness are not
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
provider verification, production readiness, or package publication. It also
does not prove an adapter is available or integration-verified. See
[Adapter Status](adapter-status.md) for the contract-complete /
adapter-available / integration-verified layers.

VFS backends, plugin hosts, scheduling, and optional integrations must be
evaluated against the specific Core's README and API reference.

## Contribution Gates

Core changes require the declared vector groups, parity inventory, API checks,
and language tests. Wire, Bridge, and Sample implementations have narrower gates.
See [language policy](../contributing/language-policy.md) and
[Core design](../contributing/core-design.md). Security-sensitive behavior requires
language-specific tests in addition to shared fixtures.
