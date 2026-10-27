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

## Matrix

| Language | Tier | Status | Tag | Maturity | Notes |
| --- | --- | --- | --- | --- | --- |
| Go | Core (reference) | released | `v2.5.0` | reference | Reference implementation |
| Python | Core | released | `python/v0.2.0` | complete | 11 vectors, OpenAI adapter |
| TypeScript | Core | released | `typescript/v0.1.0` | complete | 11 vectors, OpenAI adapter |
| Java | Core | released | `java/v0.2.1` | complete | 11 vectors, OpenAI adapter, API snapshot |
| Rust | Core | released | `rust/v0.1.0` | complete | 11 vectors, native tests; current source adds compiler-derived API/parity gate |
| C | Core | released | `c/v0.1.0` | partial | All 11 vectors; public API is wire-level |
| C# | Core (.NET) | released | `csharp/v0.1.0` | complete | 11 vectors, API snapshot, OpenAI adapter |
| Visual Basic | Sample (.NET) | released | `csharp/v0.1.0` | sample | VB.NET consumer sample in `language/csharp/samples` |
| PowerShell | Bridge | released | `powershell/v0.1.0` | complete | Wraps the bridge CLI |
| Shell | Bridge | released | `shell/v0.1.0` | complete | Wraps the bridge CLI |
| PHP | Core | released | `php/v0.1.0` | complete | 11 vectors, API snapshot, dependency-free |
| Swift | Core | released | `swift/v0.2.0` | complete | 11 vectors, XCTest, API snapshot |
| Julia | Core | released | `julia/v0.2.0` | complete | 11 vectors, JSON.jl, API snapshot |
| R | Core | released | `r/v0.2.0` | complete | 11 vectors, base-R JSON, API snapshot |
| Haskell | Wire | released | `haskell/v0.1.0` | partial | Framework target; 3 wire groups plus agent-loop vectors; Linux/Windows CI for wire groups; remote CI for loop pending |
| Fortran | Core | released | `fortran/v0.2.0` | complete | 11 vectors, native tests, API snapshot; integrated PII/middleware; source tag only; stream and schema subset partial |
| Lisp | Bridge | released | `lisp/v0.1.0` | complete | SBCL bridge over the bridge CLI; forwarding, UTF-8, errors, and exit codes verified locally and in Linux CI; consumer details pending |
| JavaScript | Sample (TypeScript) | released | none | sample | Uses the TypeScript package; no separate core |
| C++ | Core | released | `cpp/v0.1.0` | complete | 11 vectors, core tests, API snapshot |
| Dart | Core | released | `dart/v0.1.0` | complete | 11 vectors, core tests, API snapshot |
| Ruby | Core | released | `ruby/v0.1.0` | complete | 11 vectors, core tests, API snapshot |
| Kotlin | Sample (JVM) | released | none | sample | Uses the Java SDK |
| Scala | Sample (JVM) | released | none | sample | Uses the Java SDK |
| MATLAB | Wire | released | `matlab/v0.1.0` | partial | Framework target; Octave-local toolcall, JSON Schema, plugin and agent-loop vectors; MATLAB and remote CI for loop pending |
| Perl | Core | released | `perl/v0.1.0` | complete | 11 vectors, 27 tests, API snapshot |
| Delphi | Wire | released | `delphi/v0.1.0` | partial | Framework target; Free Pascal 3.2.2 local toolcall/JSON Schema/plugin and agent-loop vectors; remote CI for loop and Delphi compiler pending |
| OCaml / Caml | Core | released | `ocaml/v0.2.0` | complete | 11 vectors, native tests, API snapshot/parity; OCaml 4.14.2 bytecode; opt-in middleware integrated |
| Objective-C | Core | released | `objc/v0.1.0` | complete | 11 vectors, native tests, API snapshot/parity; opt-in middleware integrated; Windows GNUstep and macOS CI |
| Elixir | Core | released | `elixir/v0.1.0` | complete | 11 vectors, native tests, API snapshot/parity; opt-in middleware integrated |
| Nim | Core | released | `nim/v0.1.0` | complete | 11 vectors, native tests, API snapshot/parity; opt-in middleware integrated |
| V | Core | released | `v/v0.1.0` | complete | 11 vectors, native tests, API snapshot/parity; opt-in middleware integrated |
| D | Core | released | `d/v0.1.0` | complete | 11 vectors, API snapshot |
| VBScript | Bridge | planned | none | planned | Bridge over .NET or the bridge CLI |
| Erlang | Core | released | `erlang/v0.1.0` | complete | 11 vectors, native tests, API snapshot/parity; OTP 29; opt-in middleware integrated |
| Ada | Core | planned | none | planned | Native loop target; GNAT toolchain; consumer and maintainer required |
| Mojo | Core | planned | none | planned | Native loop target; toolchain and CI maturity gate |
| F# | Sample (.NET) | released | `csharp/v0.1.0` | sample | F# consumer sample in `examples/fsharp`; uses the C# SDK |
| Clojure | Sample (JVM) | released | `java/v0.2.1` | sample | Clojure consumer sample in `examples/clojure`; uses the Java SDK |
| Solidity | Wire | planned | none | planned | Candidate contract integration; scope and technical limitations require investigation |
| OpenCL | Sample | released | `c/v0.1.0` | sample | Compute integration sample in `examples/opencl`; uses the C SDK and an OpenCL ICD |
| Groovy | Sample (JVM) | released | `java/v0.2.1` | sample | Groovy consumer sample in `examples/groovy`; uses the Java SDK |
| J# | Sample (.NET) | consumer-gated | none | gated | Legacy J# runtime and toolchain are unsupported; requires a named consumer and compatible .NET path |
| FoxPro | Bridge | planned | none | planned | Bridge over the maintained runtime; Visual FoxPro is Windows-only and legacy |
| Classic Visual Basic | Bridge | planned | none | planned | Bridge over the .NET SDK or bridge CLI; VB6 cannot consume modern .NET directly |
| TCL | Bridge | released | `tcl/v0.1.0` | complete | Framework target; Tcl 8.6 wrapper over the bridge CLI; local forwarding, UTF-8, errors, and exit codes tested; remote CI pending |
| Q | Bridge | planned | none | planned | Requires a licensed kdb+/q runtime and a named consumer |
| Assembly | Bridge / extension | consumer-gated | none | gated | No portable language or ABI; target-specific binding requires a named consumer |
| Zig | Core | released | `zig/v0.2.0` | complete | 11 vectors, API snapshot; `zig/v0.1.0` remains wire |
| Lua | Core | released | `lua/v0.1.0` | complete | 11 vectors, core tests, API snapshot |
| Scratch | Bridge / extension | planned | none | planned | Extension bridge; implementation requested |
| COBOL | Core | released | `cobol/v0.1.0` | complete | 11 vectors, native/contract tests, API snapshot |
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
| C | `c-conformance` | CMake build, vectors, C core tests |
| C# / VB.NET | `csharp-conformance` | build, vectors, API snapshot, core tests, VB sample |
| PHP | `php-conformance` | vectors, API snapshot, core tests |
| Ruby | `ruby-conformance` | 11 vectors, API snapshot, tests |
| Lua | `lua-conformance` | 11 vectors, API snapshot, tests |
| Dart | `dart-conformance` | 11 vectors, API snapshot, tests |
| Zig | `zig-conformance` | 11 vectors, API snapshot, tests |
| D | `d-conformance` | 11 vectors, API snapshot, tests |
| JavaScript | `javascript-sample` | TypeScript build + Node sample |
| C++ | `cpp-conformance` | CMake build, 11 vectors, API snapshot, tests |
| Perl | `perl-conformance` | 11 vectors, API snapshot, tests |
| Swift | `swift-conformance` | swift test, 11 vectors, API snapshot |
| Julia | `julia-conformance` | Julia tests, 11 vectors, API snapshot |
| R | `r-conformance` | R tests, 11 vectors, API snapshot |
| Shell / PowerShell | `bridge` | bridge tests, both wrappers |
| Fortran | `fortran-conformance` | native tests, 11 vector groups, API snapshot; source release tagged `fortran/v0.2.0` |
| COBOL | `cobol-conformance` | 11 vectors, API snapshot, native/tooling tests |
| Haskell | `haskell-conformance` | 3 wire groups plus agent-loop vectors, native tests, source API/parity, Cabal build; source release tagged `haskell/v0.1.0`; remote CI for loop pending |
| Delphi / Free Pascal | `delphi-conformance` | 3 wire groups plus agent-loop vectors, native tests, source API/parity; source release tagged `delphi/v0.1.0`; remote CI for loop and Delphi unverified |
| OCaml | `ocaml-conformance` | 11 vectors, native tests, source API/parity; local OCaml 4.14.2 bytecode and Linux CI verified; source release tagged `ocaml/v0.2.0`; `ocamlopt` unverified |
| Objective-C | `objc-conformance` | 11 vectors, native tests, source API/parity; local clang + GNUstep verified; macOS CI verified |
| Elixir | `elixir-conformance` | 11 vectors, API snapshot, tests; OTP 29 + Elixir 1.20.4 |
| Erlang | `erlang-conformance` | 11 vectors, native tests, API snapshot/parity; OTP 29 |
| Nim | `nim-conformance` | 11 vectors, API snapshot, tests; Nim 2.2.12 |
| V | `v-conformance` | 11 vectors, API snapshot, tests; V 0.5.2 |
| Lisp | `lisp-bridge` | forwarding, UTF-8 JSON, errors, exit codes; local SBCL 2.6.9 and Linux CI verified; source release tagged `lisp/v0.1.0` |
| Tcl | `tcl-bridge` | forwarding, UTF-8 JSON, errors, exit codes; local Tcl 8.6; source release tagged `tcl/v0.1.0` |
| Prolog | `prolog-bridge` | forwarding, UTF-8 JSON, errors, exit codes; SWI-Prolog; source release tagged `prolog/v0.1.1` |
| MATLAB / Octave | `matlab-wire` | Octave: 3 wire groups plus agent-loop vectors, native tests, source API/parity; source release tagged `matlab/v0.1.0`; remote CI for loop and MATLAB unverified |
| Further languages | none yet | planned; gate depends on declared tier |

## Required Gates per Tier

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

## Toolchain Policy

Development toolchains may be installed in a developer-controlled directory.
The repository must not depend on a specific drive or user-specific install
path. CI installs the toolchain from the public distribution.

## Parity Layout

`spec/parity.md` remains the inventory for the original core languages. As new
languages land, per-language inventories are added under `spec/parity/` and the
linter enforces only the declared tier.

## Related Documents

- [Multilingual SDK design](../docs/contributing/sdk-design.md)
- [SDK support policy](../docs/languages/support.md)
- [Language implementation policy](../docs/contributing/language-policy.md)
