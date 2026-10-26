# Language Support Matrix

**Contract:** `SPEC_VERSION` `0.2.0`
**Policy:** [Language expansion plan](../docs/19-language-expansion.md)

This page is the canonical list of language implementations and their declared
scope. A language may ship more than one tier over time.

## Tiers

| Tier | Scope | Gate |
| --- | --- | --- |
| Core | Full contract: model, tool, event, policy, memory, checkpoint, context, middleware, agent | All 11 vector groups + API snapshot/parity |
| Wire | Serialization, toolcall, JSON Schema, plugin manifest, events, checkpoint envelopes | Declared wire/subset vectors |
| Bridge | Process/stdio/HTTP client over a core runtime | Bridge contract tests |
| Sample | Usage sample for another implementation | Compiles against that package |

## Matrix

| Language | Tier | Status | Tag | Notes |
| --- | --- | --- | --- | --- |
| Go | Core (reference) | released | `v2.5.0` | Reference implementation |
| Python | Core | released | `python/v0.2.0` | 11 vectors, OpenAI adapter |
| TypeScript | Core | released | `typescript/v0.1.0` | 11 vectors, OpenAI adapter |
| Java | Core | released | `java/v0.2.1` | 11 vectors, OpenAI adapter, API snapshot |
| Rust | Core | released | `rust/v0.1.0` | 11 vectors, 7 tests |
| C | Core | released | `c/v0.1.0` | All 11 vectors; public API is wire-level |
| C# | Core (.NET) | released | `csharp/v0.1.0` | 11 vectors, API snapshot, OpenAI adapter |
| Visual Basic | Sample (.NET) | released | `csharp/v0.1.0` | VB.NET consumer sample in `csharp/samples` |
| PowerShell | Bridge | released | `powershell/v0.1.0` | Wraps the bridge CLI |
| Shell | Bridge | released | `shell/v0.1.0` | Wraps the bridge CLI |
| PHP | Core | released | `php/v0.1.0` | 11 vectors, API snapshot, dependency-free |
| Swift | Core | released | `swift/v0.2.0` | 11 vectors, XCTest, API snapshot |
| Julia | Core | released | `julia/v0.2.0` | 11 vectors, JSON.jl, API snapshot |
| R | Core | released | `r/v0.2.0` | 11 vectors, base-R JSON, API snapshot |
| Haskell | Wire | planned | `haskell/v0.1.0` | Wire subset |
| Fortran | Bridge | consumer-gated | `fortran/v0.1.0` | Requires a named consumer |
| Lisp | Bridge | consumer-gated | `lisp/v0.1.0` | Requires a named consumer |
| JavaScript | Sample (TypeScript) | released | none | Uses the TypeScript package; no separate core |
| C++ | Core | released | `cpp/v0.1.0` | 11 vectors, core tests, API snapshot |
| Dart | Wire | planned | `dart/v0.1.0` | Wire first; core requires a consumer |
| Ruby | Core | released | `ruby/v0.1.0` | 11 vectors, core tests, API snapshot |
| Kotlin | Sample (JVM) | planned | none | Uses the Java SDK |
| Scala | Sample (JVM) | planned | none | Uses the Java SDK |
| MATLAB | Wire | planned | `matlab/v0.1.0` | Wire subset |
| Perl | Core | released | `perl/v0.1.0` | 11 vectors, 27 tests, API snapshot |
| Delphi | Wire / Bridge | planned | `delphi/v0.1.0` | Consumer-gated |
| OCaml / Caml | Wire | planned | `ocaml/v0.1.0` | Wire subset |
| Lua | Core | released | `lua/v0.1.0` | 11 vectors, core tests, API snapshot |
| Scratch | Bridge / extension | consumer-gated | none | Extension only |
| COBOL | Core | planned | `cobol/v0.1.0` | Core with a named consumer |
| Prolog | Bridge | consumer-gated | `prolog/v0.1.0` | Requires a named consumer |
| ABAP | Bridge | consumer-gated | `abap/v0.1.0` | Requires a named consumer |

## CI Coverage

| Language | CI job | Scope |
| --- | --- | --- |
| Go | `test` | matrix OS, test/vet/build |
| Python | `python-conformance` | vectors, parity, API snapshot, unittest |
| TypeScript | `typescript-conformance` | build, vectors, parity, API snapshot, node:test |
| Java | `java-conformance` | Maven build, vectors, API snapshot, self-tests |
| Rust | `rust-conformance` | cargo test, vectors |
| C | `c-conformance` | CMake build, vectors, C core tests |
| C# / VB.NET | `csharp-conformance` | build, vectors, API snapshot, core tests, VB sample |
| PHP | `php-conformance` | vectors, API snapshot, core tests |
| Ruby | `ruby-conformance` | 11 vectors, API snapshot, tests |
| Lua | `lua-conformance` | 11 vectors, API snapshot, tests |
| JavaScript | `javascript-sample` | TypeScript build + Node sample |
| C++ | `cpp-conformance` | CMake build, 11 vectors, API snapshot, tests |
| Perl | `perl-conformance` | 11 vectors, API snapshot, tests |
| Swift | `swift-conformance` | swift test, 11 vectors, API snapshot |
| Julia | `julia-conformance` | Julia tests, 11 vectors, API snapshot |
| R | `r-conformance` | R tests, 11 vectors, API snapshot |
| Shell / PowerShell | `bridge` | bridge tests, both wrappers |
| Haskell, Fortran, Lisp | none yet | pending toolchain or implementation |
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

- [Multilingual SDK design](../docs/17-multilingual-sdk.md)
- [Multilingual roadmap](../docs/18-multilingual-roadmap.md)
- [Language expansion plan](../docs/19-language-expansion.md)
