# Language Support Matrix

**Contract:** `SPEC_VERSION` `0.2.0`
**Policy:** [Language implementation policy](../docs/contributing/language-policy.md)

This page is the canonical list of language implementations and their declared
scope. The table records current implementation stages and delivery forms, not
permanent language categories.

Framework is the default target for independently implemented languages that
can support the shared core contract. Wire is an intermediate stage toward that
target. A final wire-only scope requires documented language/runtime technical
limitations and an explicit exception in the language's documentation and matrix.
Missing tooling or unfinished work is not such a limitation. The target does not
change today's scope, verification requirements, or release status.

`released` records a source release, not package-registry publication or a
production-readiness guarantee. Follow the [implementation support policy](../docs/languages/support.md)
and each language's installation instructions. Implementation type does not
imply every Go feature is available.

## Current Stages and Delivery Forms

| Tier | Scope | Gate |
| --- | --- | --- |
| Core | Framework implementation of the declared core contract and public API | All 11 vector groups + API snapshot/parity |
| Wire | Intermediate stage toward Framework; currently declared serialization and wire surfaces only | Declared wire/subset vectors |
| Bridge | Process/stdio/HTTP client over a core runtime | Bridge contract tests |
| Sample | Usage sample for another implementation | Compiles against that package |

## Behavior Capability Tiers

Contract tier and behavior tier are separate. Contract tier records the declared
scope and conformance gate. Behavior tier records which implementations are
targeted for cross-language agent-behavior parity in the Behavior Lab.

| Behavior tier | Languages | Scope |
| --- | --- | --- |
| Agent-capable | Go, Python, TypeScript, Java, Rust, R, C# | Native agent loop is in declared scope and the language is selected for the twenty Behavior Lab scenarios. Current coverage varies by language and is recorded in the Behavior Lab matrix. |
| Extended | PHP, C, Fortran, COBOL, Ruby, Elixir, Erlang, C++, Lua | Contract or focused implementation where behavior parity is advanced scenario by scenario. An unsupported cell is intentional until a named consumer and maintainer exist. |
| Optional | Other declared implementations | Outside the current Behavior Lab program. Contract conformance is unchanged; behavior work starts only with a named consumer and maintainer. |

All sixteen wired languages cover all twenty scenarios in the source. Extended
implementations use native-suite coverage; parallel tools for COBOL, Lua, PHP,
and Fortran delegate concurrency to caller-provided batch callbacks.
Other implementations, including Swift, Julia, Haskell, MATLAB/Octave,
Perl, Delphi/Free Pascal, OCaml, Objective-C, Nim, V, D, Zig, and the
Bridge/Sample entries, are in the optional tier.

## Maturity

Maturity is independent of the version tag. It records completion of the
declared scope and verification against the tier gate. It does not imply
production readiness or full Go feature parity.

| Maturity | Meaning |
| --- | --- |
| `reference` | Go reference implementation. |
| `complete` | Released with all declared-scope gates passing. |
| `partial` | Released with documented scope gaps or pending required runtime/CI verification. |
| `sample` | Usage sample of another implementation, not an independent runtime. |
| `planned` | Planned; no source tag. |
| `gated` | Requires a named consumer or compatible runtime before implementation starts. |

`complete` describes contract conformance for the declared scope. It is not a
statement that every feature-coverage row in [the parity inventory](parity.md)
is `parity`; some rows may remain `partial` or `planned`. Operational evidence
for real providers, platforms, and production behavior is reported separately.

## Matrix

| Language | Tier | Status | Tag | Maturity | Notes |
| --- | --- | --- | --- | --- | --- |
| Go | Core (reference) | released | `v2.6.0` | reference | Reference implementation |
| Python | Core | released | `python/v0.3.2` | complete | 11 vectors, HITL interrupts, OpenAI adapter, PyPI `praxo-core==0.3.2` |
| TypeScript | Core | released | `typescript/v0.2.2` | complete | 11 vectors, HITL interrupts, OpenAI adapter; npm `@axisvela/praxo-core@0.2.1` published with provenance, `0.2.2` staged for maintainer approval |
| Java | Core | released | `java/v0.4.1` | complete | 11 vectors, HITL interrupts, OpenAI adapter, API snapshot; Maven Central `com.axisvela:praxo-core:0.4.1` |
| Rust | Core | released | `rust/v0.3.0` | complete | 11 vectors, HITL interrupts, native tests, `tool.Gateway`, `jsonschema.Schema`, streaming/cancellation/parallel tools, compiler-derived API/parity gate; source `0.3.0`, crates.io `praxo-core==0.3.0`; recorded install smoke covers `0.1.4` |
| C | Core | released | `c/v0.6.0` | complete | 11 vectors, native tests; public Core API plus wire JSON primitives; policy/middleware/lifecycle, HITL interrupt decisions, cancellation, streaming, SSE, bounded parallel tools (pthread on Unix; sequential on Windows) |
| C# | Core (.NET) | released | `csharp/v0.3.0` | complete | 11 vectors, HITL interrupts, API snapshot, OpenAI adapter, streaming/cancellation/parallel tools; source `0.3.0`, NuGet `Praxo.Core==0.3.0` |
| Visual Basic | Sample (.NET) | released | `csharp/v0.1.1` | sample | VB.NET consumer sample in `language/csharp/samples` |
| PowerShell | Core (.NET) | released | `powershell/v0.2.0` | complete | C# shared-runtime Core wrapper; PowerShell Gallery `praxo-core-ps==0.2.0`; 11 vectors via C# Core; PowerShell API snapshot/parity; agent loop delegated to C# Core |
| Shell | Bridge | released | `shell/v0.1.0` | complete | Wraps the bridge CLI |
| PHP | Core | released | `php/v0.4.0` | complete | 11 vectors, HITL interrupts, API snapshot, streaming/cancellation/SSE, and caller-provided cooperative parallel tools; source `0.4.0`, Packagist `axisvela/praxo-core==0.4.0` |
| Swift | Core | released | `swift/v0.2.0` | complete | 11 vectors, XCTest, API snapshot; split SPM repo `axisvela/praxo-core-swift` tag `0.2.0`; SPI PR #16032 open |
| Julia | Core | released | `julia/v0.2.0` | complete | 11 vectors, JSON.jl, API snapshot; mirror `axisvela/praxo-core-julia` tag `0.2.0`; General Registry PR #174826 open |
| R | Core | released | `r/v0.5.0` | complete | 11 vectors, base-R JSON, policy/middleware, HITL interrupts, lifecycle cleanup, cancellation, streaming, SSE parser, bounded parallel tools, API snapshot |
| Haskell | Core | released | `haskell/v0.2.0` | complete | 11 vectors, native tests, API snapshot/parity; GHC 9.12.2; runtime and middleware helpers |
| Fortran | Core | released | `fortran/v0.6.0` | complete | 11 vectors, HITL interrupts, native tests, API snapshot; upstream RE2/Unicode patterns, cancellation, streaming, SSE, and caller-provided batch tools; JSON/schema limits remain documented |
| Lisp | Bridge | released | `lisp/v0.1.0` | complete | SBCL bridge over the bridge CLI; forwarding, UTF-8, errors, and exit codes verified locally and in Linux CI; consumer details pending |
| JavaScript | Sample (TypeScript) | released | none | sample | Uses the TypeScript package; no separate core |
| C++ | Core | released | `cpp/v0.4.0` | complete | 11 vectors, HITL interrupts, core tests, API snapshot, middleware/lifecycle authorization, cancellation, streaming, SSE, parallel tools, and run-scoped call limits |
| Dart | Core | released | `dart/v0.1.1` | complete | 11 vectors, core tests, API snapshot; pub.dev `praxo_core==0.1.1` |
| Ruby | Core | released | `ruby/v0.4.1` | complete | 11 vectors, HITL interrupts, core tests, API snapshot, middleware/lifecycle authorization, cancellation, streaming, SSE, parallel tools, and run-scoped call limits; source `0.4.1`, Ruby source repo `axisvela/praxo-core-ruby`, RubyGems `praxo-core==0.4.1` |
| Kotlin | Sample (JVM) | released | none | sample | Uses the Java Core |
| Scala | Sample (JVM) | released | none | sample | Uses the Java Core |
| MATLAB | Core | released | `matlab/v0.2.1` | complete | 11 vectors, native tests, API snapshot/parity; MATLAB File Exchange `185166`; MATLAB runtime unverified |
| Octave | Core | released | `octave/v0.2.1` | complete | 11 vectors, native tests, API snapshot/parity under GNU Octave 11.3.0; Octave Packages PR #875 open |
| Perl | Core | released | `perl/v0.1.1` | complete | 11 vectors, 27 tests, API snapshot; distribution root package `Praxo::Core` |
| Delphi | Core | released | `delphi/v0.2.1` | complete | 11 vectors, native tests, API snapshot/parity; Free Pascal 3.2.2; commercial Delphi unverified |
| OCaml / Caml | Core | released | `ocaml/v0.3.0` | complete | 11 vectors, native tests, API snapshot/parity; OCaml 4.14.2 bytecode; module `Praxo_core`; opt-in middleware integrated |
| Objective-C | Core | released | `objc/v0.1.1` | complete | 11 vectors, native tests, API snapshot/parity; opt-in middleware integrated; Windows GNUstep and macOS CI |
| Elixir | Core | released | `elixir/v0.4.0` | complete | 11 vectors, HITL interrupts, native tests, API snapshot/parity, policy/middleware/lifecycle, cancellation, streaming, SSE, parallel tools, and run-scoped call limits; source `0.4.0`, Hex `praxo_core==0.4.0` |
| Nim | Core | released | `nim/v0.1.1` | complete | 11 vectors, native tests, API snapshot/parity; opt-in middleware integrated |
| V | Core | released | `v/v0.1.2` | complete | 11 vectors, native tests, API snapshot/parity; opt-in middleware integrated; split VPM repo `axisvela/praxo-core-v` package `praxo-core` tag `0.1.2`; VPM submission pending |
| D | Core | released | `d/v0.1.0` | complete | 11 vectors, API snapshot; DUB/code.dlang.org `praxo-core==0.1.0` |
| VBScript | Bridge | planned | none | planned | Bridge over .NET or the bridge CLI |
| Erlang | Core | released | `erlang/v0.4.0` | complete | 11 vectors, HITL interrupts, native tests, API snapshot/parity, policy/middleware/lifecycle, cancellation, streaming, SSE, parallel tools, and run-scoped call limits; OTP 29; source `0.4.0`, Hex `praxo_core_erlang==0.4.0` |
| Ada | Core | planned | none | planned | Native loop target; GNAT toolchain; consumer and maintainer required |
| Mojo | Core | planned | none | planned | Native loop target; toolchain and CI maturity gate |
| F# | Sample (.NET) | released | `csharp/v0.1.1` | sample | F# consumer sample in `examples/fsharp`; uses the C# Core |
| Clojure | Sample (JVM) | released | `java/v0.2.2` | sample | Clojure consumer sample in `examples/clojure`; uses the Java Core |
| Solidity | Wire | planned | none | planned | Candidate contract integration; scope and technical limitations require investigation |
| OpenCL | Sample | released | `c/v0.2.0` | sample | Compute integration sample in `examples/opencl`; uses the C Core and an OpenCL ICD |
| Groovy | Sample (JVM) | released | `java/v0.2.2` | sample | Groovy consumer sample in `examples/groovy`; uses the Java Core |
| J# | Sample (.NET) | consumer-gated | none | gated | Legacy J# runtime and toolchain are unsupported; requires a named consumer and compatible .NET path |
| FoxPro | Bridge | planned | none | planned | Bridge over the maintained runtime; Visual FoxPro is Windows-only and legacy |
| Classic Visual Basic | Bridge | planned | none | planned | Bridge over the .NET Core or bridge CLI; VB6 cannot consume modern .NET directly |
| TCL | Bridge | released | `tcl/v0.1.0` | complete | Framework target; Tcl 8.6 wrapper over the bridge CLI; forwarding, UTF-8, errors, and exit codes tested locally and in Linux CI; package-registry publication pending |
| Q | Bridge | planned | none | planned | Requires a licensed kdb+/q runtime and a named consumer |
| Assembly | Bridge / extension | consumer-gated | none | gated | No portable language or ABI; target-specific binding requires a named consumer |
| Zig | Core | released | `zig/v0.2.0` | complete | 11 vectors, API snapshot; `zig/v0.1.0` remains wire |
| Lua | Core | released | `lua/v0.4.0` | complete | 11 vectors, HITL interrupts, core tests, API snapshot, middleware/lifecycle authorization, cancellation, streaming, SSE, and batch tool dispatch; source `0.4.0`, rockspec `0.4.0-1`, LuaRocks `praxo-core==0.4.0-1`; release workflow |
| Scratch | Bridge / extension | planned | none | planned | Extension bridge; implementation requested |
| COBOL | Core | released | `cobol/v0.4.0` | complete | 11 vectors, HITL interrupts, native/contract tests, API snapshot; caller-owned scoped registries, native agent consumer fixtures, and middleware/lifecycle/cancellation/streaming/SSE/batch-dispatch behavior coverage |
| Prolog | Bridge | released | `prolog/v0.1.1` | complete | SWI-Prolog wrapper over the bridge CLI; forwarding, UTF-8, errors, and exit codes tested |
| ABAP | Bridge | planned | none | planned | Bridge over the maintained runtime |

## CI Coverage

| Language | CI job | Scope |
| --- | --- | --- |
| Go | `test` | matrix OS, test/vet/build |
| Python | `python-conformance` | vectors, parity, API snapshot, unittest |
| TypeScript | `typescript-conformance` | build, vectors, parity, API snapshot, node:test |
| Java | `java-conformance` | Maven build, vectors, API snapshot, self-tests |
| Rust | `rust-conformance` | cargo test, vectors, compiler-derived API snapshot/parity, gate regressions |
| C | `c-conformance` | CMake build, 11 vectors, API snapshot, public Core API tests, inventory negative controls, installed-library consumer |
| C# / VB.NET | `csharp-conformance` | build, vectors, API snapshot, core tests, VB sample |
| PHP | `php-conformance` | vectors, API snapshot, native tests |
| Ruby | `ruby-conformance` | 11 vectors, API snapshot, native tests |
| Lua | `lua-conformance` | 11 vectors, API snapshot, native tests |
| Dart | `dart-conformance` | 11 vectors, API snapshot, tests |
| Zig | `zig-conformance` | 11 vectors, API snapshot, tests |
| D | `d-conformance` | 11 vectors, API snapshot, tests |
| JavaScript | `javascript-sample` | TypeScript build + Node sample |
| C++ | `cpp-conformance` | CMake build, 11 vectors, API snapshot, native tests |
| Perl | `perl-conformance` | 11 vectors, API snapshot, tests |
| Swift | `swift-conformance` | swift test, 11 vectors, API snapshot |
| Julia | `julia-conformance` | Julia tests, 11 vectors, API snapshot |
| R | `r-conformance` | R tests, 11 vectors, API snapshot |
| PowerShell Core | `powershell-core` | C# Core build, 11 vectors, C# behavior tests, PowerShell API snapshot, wrapper smoke tests |
| PowerShell Bridge | `powershell-bridge-release` | bridge tests, bundled Linux/Windows/macOS binaries, PowerShell Gallery publication |
| Shell / PowerShell Bridge | `bridge` | bridge tests, both wrappers |
| Fortran | `fortran-conformance` | native tests, 11 vector groups, API snapshot, installed RE2 bridge and Unicode tests; source release tagged `fortran/v0.6.0` |
| COBOL | `cobol-conformance` | 11 vectors, API snapshot, native/behavior/SSE/tooling tests |
| Haskell | `haskell-conformance` | 11 vectors, native tests, source API/parity, Cabal build; source release tagged `haskell/v0.2.0` |
| Delphi / Free Pascal | `delphi-conformance` | 11 vectors, native tests, source API/parity; source release tagged `delphi/v0.2.1`; commercial Delphi unverified |
| OCaml | `ocaml-conformance` | 11 vectors, native tests, source API/parity; local OCaml 4.14.2 bytecode and Linux CI verified; source release tagged `ocaml/v0.3.0`; `ocamlopt` unverified |
| Objective-C | `objc-conformance` | 11 vectors, native tests, source API/parity; local clang + GNUstep verified; macOS CI verified |
| Elixir | `elixir-conformance` | 11 vectors, API snapshot, native tests; OTP 29 + Elixir 1.20.4 |
| Erlang | `erlang-conformance` | 11 vectors, native tests, API snapshot/parity, OTP 29 |
| Nim | `nim-conformance` | 11 vectors, API snapshot, tests; Nim 2.2.12 |
| V | `v-conformance` | 11 vectors, API snapshot, tests; V 0.5.2 |
| Lisp | `lisp-bridge` | forwarding, UTF-8 JSON, errors, exit codes; local SBCL 2.6.9 and Linux CI verified; source release tagged `lisp/v0.1.0` |
| Tcl | `tcl-bridge` | forwarding, UTF-8 JSON, errors, exit codes; local Tcl 8.6; source release tagged `tcl/v0.1.0` |
| Prolog | `prolog-bridge` | forwarding, UTF-8 JSON, errors, exit codes; SWI-Prolog; source release tagged `prolog/v0.1.1` |
| MATLAB | `matlab-conformance` | 11 vectors, native tests, source API/parity; source release tagged `matlab/v0.2.1`; MATLAB runtime unverified |
| Octave | `octave-conformance`, `octave-package` | 11 vectors, native tests, source API/parity; source release tagged `octave/v0.2.1`; Octave package archive install smoke |
| Further languages | none yet | planned; gate depends on declared tier |

## Required Gates per Contract Tier

### Core

- All 11 groups in `spec/vectors`.
- API snapshot checked into the language tree.
- Parity inventory for the declared scope.
- CI job for build, vectors, and tests.
- Wire names preserve the Go casing, including `image_url` and `runId`.

### Wire

- `toolcall`, `jsonschema`, `plugin`, and the declared wire fixtures.
- No agent loop or provider adapter is implied.
- Error codes match `spec/wire/errors.json`.

### Bridge

- `spec/bridge.md` commands and JSON-Lines framing.
- Error codes and exit codes match the bridge contract.
- No rewriting of tool-call markup or policy decisions.

### Sample

- Compiles against the host package.
- Documented as a sample, not a contract implementation.

## Required Gates per Behavior Tier

### Agent-capable

- Runs the shared Behavior Lab scenarios or records an explicit unsupported
  reason for each missing cell.
- Scenario tests preserve authorization, lifecycle, cancellation, and ordering
  semantics; suite-only coverage does not count as scenario-level evidence.
- C# and R must complete scenario wiring before their agent-capable claim is
  treated as full behavior parity.

### Extended

- Advances selected scenarios only with a named consumer and maintainer.
- Does not add a language or scenario solely to increase cell counts.
- Unsupported cells stay explicit in the report and matrix.

### Optional

- No Behavior Lab scenario work is planned by default.
- Contract conformance and the declared contract tier remain unchanged.
- Promotion to extended or agent-capable requires a named consumer, a
  maintainer, and recorded scenario evidence.

## Toolchain Policy

Development toolchains may be installed in a developer-controlled directory.
The repository must not depend on a specific drive or user-specific install
path. CI installs the toolchain from the public distribution.

## Parity Layout

`spec/parity.md` remains the inventory for the original core languages. As new
languages land, per-language inventories are added under `spec/parity/` and the
linter enforces only the declared tier.

## Related Documents

- [Multilingual Core design](../docs/contributing/core-design.md)
- [Core support policy](../docs/languages/support.md)
- [Language implementation policy](../docs/contributing/language-policy.md)
