# Language Implementations

Choose your language, then follow its installation or source-build instructions.
Go is the reference implementation; other implementations share the declared
contract, not necessarily every Go feature. Read the [support policy](support.md)
and the [canonical scope matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md).

[View all languages and their current status](matrix.md){ .md-button }

Framework is the default target for independently implemented, native-capable
languages. Current Wire stages do not yet provide the full Framework; final
wire-only scope requires documented technical limitations. See the
[support policy](support.md) for the distinction between current scope and target.

## Native Implementations

| Language | Entry point |
| --- | --- |
| Go | [Install and quickstart](go.md) |
| Python | [Python SDK](python.md) |
| TypeScript | [TypeScript SDK](typescript.md) |
| Java | [Java SDK](java.md) |
| Rust | [Rust SDK](rust.md) |
| C | [C SDK](c.md), currently a wire-level public API |
| C++ | [C++ SDK](cpp.md) |
| C# / .NET | [C# SDK](csharp.md) |
| PHP | [PHP SDK](php.md) |
| Ruby | [Ruby SDK](ruby.md) |
| Perl | [Perl SDK](perl.md) |
| Lua | [Lua SDK](lua.md) |
| Dart | [Dart SDK](dart.md) |
| Swift | [Swift SDK](swift.md) |
| Julia | [Julia SDK](julia.md) |
| R | [R SDK](r.md) |
| D | [D SDK](d.md) |
| Zig | [Zig SDK](zig.md) |
| COBOL | [COBOL SDK](cobol.md) |
| Fortran | [Fortran implementation](fortran.md) |
| Elixir | [Elixir SDK](elixir.md) |
| Erlang | [Erlang SDK](erlang.md) |
| Nim | [Nim SDK](nim.md) |
| V | [V SDK](v.md) |
| Objective-C | [Objective-C SDK](objective-c.md) |
| OCaml / Caml | [OCaml SDK](ocaml.md) |

## Shared-Runtime Samples and Bridges

| Language | Implementation |
| --- | --- |
| JavaScript | [Sample using TypeScript](javascript.md) |
| Kotlin | [Sample using Java](kotlin.md) |
| Scala | [Sample using Java](scala.md) |
| Groovy | [Sample using Java](groovy.md) |
| Clojure | [Sample using Java](clojure.md) |
| OpenCL | [Compute sample using C](opencl.md) |
| Visual Basic | [Sample using .NET](visual-basic.md) |
| F# | [Sample using .NET](fsharp.md) |
| Shell | [Runtime bridge](shell.md) |
| PowerShell | [Runtime bridge](powershell.md) |
| Lisp | [SBCL runtime bridge](lisp.md) |
| Tcl | [Runtime bridge](tcl.md) |
| Prolog | [SWI-Prolog runtime bridge](prolog.md) |

## Wire Implementations

[Haskell](haskell.md) has source tag `haskell/v0.1.0`. It targets a native
Framework. Three wire groups and an experimental agent loop pass locally; remote
CI for the loop remains pending. No Hackage package or delivery date is claimed.

[MATLAB / Octave](matlab.md) has source tag `matlab/v0.1.0`. It targets a native
Framework. Three wire groups and agent-loop vectors pass locally in Octave;
MATLAB and remote CI for the loop have not yet been verified.

[Delphi / Free Pascal](delphi.md) has source tag `delphi/v0.1.0`. It targets a
native Framework. Three wire groups and agent-loop vectors pass locally with Free
Pascal 3.2.2 on Windows i386; remote CI for the loop and the Delphi compiler
remain unverified.

Source tags, registry publication, conformance, and production verification are
different states. A language page includes the source README so installation,
examples, and limitations stay aligned with the implementation.
