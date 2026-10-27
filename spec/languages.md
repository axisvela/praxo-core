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

## Matrix

| Language | Tier | Status | Tag | Notes |
| --- | --- | --- | --- | --- |
| Go | Core (reference) | released | `v2.5.0` | Reference implementation |
| Python | Core | released | `python/v0.2.0` | 11 vectors, OpenAI adapter |
| TypeScript | Core | released | `typescript/v0.1.0` | 11 vectors, OpenAI adapter |
| Java | Core | released | `java/v0.2.1` | 11 vectors, OpenAI adapter, API snapshot |
| Rust | Core | released | `rust/v0.1.0` | 11 vectors, native tests; current source adds compiler-derived API/parity gate |
| C | Core | released | `c/v0.1.0` | All 11 vectors; public API is wire-level |
| C# | Core (.NET) | released | `csharp/v0.1.0` | 11 vectors, API snapshot, OpenAI adapter |
| Visual Basic | Sample (.NET) | released | `csharp/v0.1.0` | VB.NET consumer sample in `language/csharp/samples` |
| PowerShell | Bridge | released | `powershell/v0.1.0` | Wraps the bridge CLI |
| Shell | Bridge | released | `shell/v0.1.0` | Wraps the bridge CLI |
| PHP | Core | released | `php/v0.1.0` | 11 vectors, API snapshot, dependency-free |
| Swift | Core | released | `swift/v0.2.0` | 11 vectors, XCTest, API snapshot |
| Julia | Core | released | `julia/v0.2.0` | 11 vectors, JSON.jl, API snapshot |
| R | Core | released | `r/v0.2.0` | 11 vectors, base-R JSON, API snapshot |
| Haskell | Wire | in progress | none | Framework target; currently 24 vectors in 3 wire groups, native tests, API snapshot/parity; Linux/Windows CI verified, release review pending |
| Fortran | Core | in progress | none | 11 vector groups, native tests, API snapshot; CI job verified, release review pending |
| Lisp | Bridge | consumer-gated | none | Requires a named consumer |
| JavaScript | Sample (TypeScript) | released | none | Uses the TypeScript package; no separate core |
| C++ | Core | released | `cpp/v0.1.0` | 11 vectors, core tests, API snapshot |
| Dart | Core | released | `dart/v0.1.0` | 11 vectors, core tests, API snapshot |
| Ruby | Core | released | `ruby/v0.1.0` | 11 vectors, core tests, API snapshot |
| Kotlin | Sample (JVM) | released | none | Uses the Java SDK |
| Scala | Sample (JVM) | released | none | Uses the Java SDK |
| MATLAB | Wire | in progress | none | Framework target; Octave-local toolcall, JSON Schema and plugin vector groups; MATLAB and remote CI not yet verified |
| Perl | Core | released | `perl/v0.1.0` | 11 vectors, 27 tests, API snapshot |
| Delphi | Wire / Bridge | planned | none | Consumer-gated |
| OCaml / Caml | Core | planned | none | Requires a consumer and maintenance owner before a native loop |
| D | Core | released | `d/v0.1.0` | 11 vectors, API snapshot |
| Objective-C | Core | planned | none | Requires a consumer and maintenance owner before a native loop |
| VBScript | Bridge | planned | none | Bridge over .NET or the bridge CLI |
| Zig | Core | released | `zig/v0.2.0` | 11 vectors, API snapshot; `zig/v0.1.0` remains wire |
| Lua | Core | released | `lua/v0.1.0` | 11 vectors, core tests, API snapshot |
| Scratch | Bridge / extension | consumer-gated | none | Extension only |
| COBOL | Core | released | `cobol/v0.1.0` | 11 vectors, native/contract tests, API snapshot |
| Prolog | Bridge | consumer-gated | none | Requires a named consumer |
| ABAP | Bridge | consumer-gated | none | Requires a named consumer |

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
| Fortran | `fortran-conformance` | native tests, 11 vector groups, API snapshot; release pending |
| COBOL | `cobol-conformance` | 11 vectors, API snapshot, native/tooling tests |
| Haskell | `haskell-conformance` | Linux/Windows: 3 wire groups, native tests, source API/parity, Cabal build |
| MATLAB / Octave | `matlab-wire` | Octave: 3 wire groups, native tests, source API/parity; remote evidence pending; MATLAB unverified |
| Lisp | none yet | consumer-gated bridge |
| Objective-C, OCaml | none yet | core planned |
| Wave 2 languages | none yet | planned; gate depends on declared tier |

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
