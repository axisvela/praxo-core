# Language Implementations

Choose your language, then follow its installation or source-build instructions.
Go is the reference implementation; other implementations share the declared
contract, not necessarily every Go feature. Read the [support policy](support.md)
and the [canonical scope matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md).

[View all languages and their current status](matrix.md){ .md-button }

See [registry publication status](registry-status.md) for package names, versions,
addresses, and pending releases. See [language repositories](repositories.md) for
the dedicated repository index across all implemented languages.

Each entry has its own docs/languages/<language>/ directory for the Core page and future examples, adapter notes, and release pages.

See the [compatibility lab](compatibility-lab.md) for reproducible conformance
evidence across selected implementations, and the [behavior lab](behavior-lab.md)
for cross-language agent behavior scenarios. Behavior coverage uses separate
agent-capable, extended, and optional tiers; see the [support policy](support.md).

Framework is the default target for independently implemented, native-capable
languages. Current Wire stages do not yet provide the full Framework; final
wire-only scope requires documented technical limitations. See the
[support policy](support.md) for the distinction between current scope and target.

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
