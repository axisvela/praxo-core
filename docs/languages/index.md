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
| Fortran | [Fortran implementation](fortran.md), in progress |

## Shared-Runtime Samples and Bridges

| Language | Implementation |
| --- | --- |
| JavaScript | [Sample using TypeScript](javascript.md) |
| Kotlin | [Sample using Java](kotlin.md) |
| Scala | [Sample using Java](scala.md) |
| Visual Basic | [Sample using .NET](visual-basic.md) |
| Shell | [Runtime bridge](shell.md) |
| PowerShell | [Runtime bridge](powershell.md) |
| Lisp | [SBCL runtime bridge](lisp.md) |

## Wire Candidates

[Haskell](haskell.md) is an unreleased Wire-stage implementation targeting a
native Framework, with 24 vectors in three declared groups. It does not currently
include an agent loop. Linux and Windows CI have passed; release review remains
pending. No Hackage package, release tag, or delivery date is claimed.

[MATLAB / Octave](matlab.md) is an unreleased Wire-stage candidate targeting a
native Framework. Three vector groups pass locally in Octave; MATLAB and remote
CI have not yet been verified.

[Delphi / Free Pascal](delphi.md) is an unreleased Wire-stage candidate targeting
a native Framework. Three vector groups pass locally with Free Pascal 3.2.2 on
Windows i386 and in Linux CI; the Delphi compiler remains unverified.

[OCaml](ocaml.md) is an unreleased Wire-stage candidate targeting a native
Framework. Three vector groups pass locally with OCaml 4.14.2 bytecode and in
Linux CI; native `ocamlopt` compilation remains unverified.

[Objective-C](objective-c.md) is an unreleased Wire-stage candidate targeting a
native Framework. Three vector groups pass locally with clang and GNUstep Base
on Windows; Apple Foundation and macOS CI remain pending.

Source tags, registry publication, conformance, and production verification are
different states. A language page includes the source README so installation,
examples, and limitations stay aligned with the implementation.
