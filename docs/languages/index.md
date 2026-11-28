# Language Implementations

Choose your language, then follow its installation or source-build instructions.
Go is the reference implementation; other implementations share the declared
contract, not necessarily every Go feature. Read the [support policy](support.md)
and the [canonical scope matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md).

[View all languages and their current status](matrix.md){ .md-button }

See [registry publication status](registry-status.md) for package names, versions,
addresses, and pending releases. See [language repositories](repositories.md) for
the dedicated repository index across all implemented languages, and
[adapter status](adapter-status.md) for Model, MCP, and Harmovela coverage.

Each entry has its own docs/languages/<language>/ directory for the Core page,
adapter notes, and release pages. Language-specific runnable examples live in
`language/<language>/examples/` and are included in the dedicated language
mirror repositories.

## What You Can Build Today

Choose the group that matches the result you need, then verify the language page,
package registry, and example README. These are build-oriented paths, not support
tiers or production-readiness claims.

| Path | Languages | What you get | Boundary |
| --- | --- | --- | --- |
| Published-package governed starter | Go, Python, TypeScript, Java | Install or build from a published package, run a deterministic model, and pass allow/deny plus governed negative checks | One recorded package revision per language; not adoption or production evidence |
| Published-package allow/deny starter | Ruby, PHP, Elixir, Lua | A published package, deterministic allow/deny, and source examples | Consumer starters; the governed negative matrix remains scoped to the four pilot languages |
| Published package or source release with runnable examples | Rust, C#, R, Dart, Erlang, Haskell, Perl, PowerShell | A registry or r-universe release plus deterministic examples for HITL, streaming, checkpoints, and related themes | Registry versions can lag source tags; check registry status and example depth |
| Source Core with deterministic examples | C, C++, Fortran, COBOL, Julia, MATLAB/Octave, Swift, D, Nim, V, Zig, OCaml, Objective-C, Delphi / Free Pascal | Build from source and run deterministic examples, including HITL and session checkpoints | Some registry submissions are pending; platform and toolchain limits remain documented per language |
| Shared-runtime sample | JavaScript, Kotlin, Scala, Groovy, Clojure, Visual Basic, F# | A usage sample over the TypeScript, Java, or .NET Core | Not an independent runtime or separately versioned package |
| Bridge | Shell, Lisp, Tcl, Prolog | A process or CLI bridge over the maintained runtime | No local agent loop or delegation surface |

A source entry is not an execution certificate. See the
[example depth audit](../getting-started/language-coverage.md#depth-audit) for
which themes invoke Core and which are mechanism checks, and
[verification evidence](../project/verification-evidence.md) for recorded runs.

See the [compatibility lab](compatibility-lab.md) for reproducible conformance
evidence across selected implementations, and the [behavior lab](behavior-lab.md)
for cross-language agent behavior scenarios. Behavior evidence has no capability
tier; see [Behavior Evidence](support.md#behavior-evidence).

Framework is the default target for independently implemented, native-capable
languages. Current Wire stages do not yet provide the full Framework; final
wire-only scope requires documented technical limitations. See the
[support policy](support.md) for the distinction between current scope and target.

## Ecosystem Categories

These are descriptive discovery tags, not support tiers, release gates, or a
priority ranking. A language can appear in more than one category. Contract
scope remains in the [matrix](matrix.md); behavior evidence and limits remain in
the [support policy](support.md).

| Category | Languages | How to read it |
| --- | --- | --- |
| Mainstream | Go, Python, TypeScript / JavaScript, Java, C#, C, C++, Rust, PHP, Ruby, Swift, Kotlin, Scala | Broad ecosystem and tooling; JavaScript, Kotlin, and Scala are samples over another Core |
| Emerging | Zig, V, Nim, Swift, Dart, Kotlin, Solidity (planned), Mojo (planned) | Newer or fast-moving ecosystems; planned entries are not available |
| Legacy | COBOL, Fortran, Ada (planned), Delphi / Free Pascal, Objective-C, Perl, Visual Basic, VBScript (planned), FoxPro (planned), Classic Visual Basic (planned), J# (gated) | Maintenance and integration paths; planned or gated entries are not releases |
| Data | R, Julia, MATLAB, Octave, Python, Fortran | Analysis, numerical, and HPC workflows |
| AI | Python, R, Julia, Mojo (planned), C++, Rust | Model integration and inference tooling; Core does not supply models or hosting |
| Local / embedded | C, C++, Rust, Zig, D, Ada (planned), Assembly (gated), OpenCL (sample) | Native runtimes, devices, and compute boundaries |
| Scripting / automation | Python, JavaScript, Ruby, Perl, PHP, Lua, Shell, PowerShell, Tcl | Glue, operations, and local automation |
| Niche / domain-specific | Haskell, OCaml, F#, Clojure, Lisp, Prolog, Erlang, Elixir, Tcl, Zig, V, Nim | Focused ecosystems with smaller maintainer pools |
| Candidate / planned | Ada, Mojo, Solidity, VBScript, FoxPro, Q, Assembly, Scratch, ABAP, J# (gated) | Requires a named consumer, maintainer, or compatible runtime before work starts |

Use the categories to choose a likely starting point, then verify the language
page, package registry, and example README. A category does not imply production
readiness or full Go feature parity.

## Native Implementations

| Language | Entry point |
| --- | --- |
| Go | [Install and quickstart](go/index.md) |
| Python | [Python Core](python/index.md) |
| TypeScript | [TypeScript Core](typescript/index.md) |
| Java | [Java Core](java/index.md) |
| Rust | [Rust Core](rust/index.md) |
| C | [C Core](c/index.md) |
| C++ | [C++ Core](cpp/index.md) |
| C# / .NET | [C# Core](csharp/index.md) |
| PHP | [PHP Core](php/index.md) |
| Ruby | [Ruby Core](ruby/index.md) |
| Perl | [Perl Core](perl/index.md) |
| Lua | [Lua Core](lua/index.md) |
| Dart | [Dart Core](dart/index.md) |
| Swift | [Swift Core](swift/index.md) |
| Julia | [Julia Core](julia/index.md) |
| R | [R Core](r/index.md) |
| D | [D Core](d/index.md) |
| Zig | [Zig Core](zig/index.md) |
| COBOL | [COBOL Core](cobol/index.md) |
| Fortran | [Fortran Core](fortran/index.md) |
| Elixir | [Elixir Core](elixir/index.md) |
| Erlang | [Erlang Core](erlang/index.md) |
| Nim | [Nim Core](nim/index.md) |
| V | [V Core](v/index.md) |
| Objective-C | [Objective-C Core](objective-c/index.md) |
| OCaml / Caml | [OCaml Core](ocaml/index.md) |
| MATLAB | [MATLAB Core](matlab/index.md) |
| Octave | [Octave Core](octave/index.md) |
| Haskell | [Haskell Core](haskell/index.md) |
| Delphi / Free Pascal | [Delphi / Free Pascal Core](delphi/index.md) |

## Shared-Runtime Samples and Bridges

| Language | Implementation |
| --- | --- |
| JavaScript | [Sample using TypeScript](javascript/index.md) |
| Kotlin | [Sample using Java](kotlin/index.md) |
| Scala | [Sample using Java](scala/index.md) |
| Groovy | [Sample using Java](groovy/index.md) |
| Clojure | [Sample using Java](clojure/index.md) |
| OpenCL | [Compute sample using C](opencl/index.md) |
| Visual Basic | [Sample using .NET](visual-basic/index.md) |
| F# | [Sample using .NET](fsharp/index.md) |
| Shell | [Runtime bridge](shell/index.md) |
| PowerShell | [PowerShell Core](powershell/index.md) |
| Lisp | [SBCL runtime bridge](lisp/index.md) |
| Tcl | [Runtime bridge](tcl/index.md) |
| Prolog | [SWI-Prolog runtime bridge](prolog/index.md) |

Source tags, registry publication, conformance, and production verification are
different states. A language page includes the source README so installation,
examples, and limitations stay aligned with the implementation.
