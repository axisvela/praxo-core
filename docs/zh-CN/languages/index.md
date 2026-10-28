# 语言实现

先选择语言，再按对应页面安装或从源码构建。Go 是参考实现；共享契约不代表
所有语言都有 Go 的全部功能。请先阅读[支持政策](support.md)与
[规范支持矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)。

[查看全部语言与当前状态](matrix.md){ .md-button }

具备原生实现能力的独立语言默认以 Framework 为最终目标。处于 Wire 阶段的实现
当前尚不提供完整 Framework；仅有明确的技术限制时才以 Wire 为最终范围。当前能力
和最终目标的区别见[支持政策](support.md)。

## 原生实现

| 语言 | 使用入口 |
| --- | --- |
| Go | [安装与快速开始](go.md) |
| Python | [Python Core](python.md) |
| TypeScript | [TypeScript Core](typescript.md) |
| Java | [Java Core](java.md) |
| Rust | [Rust Core](rust.md) |
| C | [C Core](c.md) |
| C++ | [C++ Core](cpp.md) |
| C# / .NET | [C# Core](csharp.md) |
| PHP | [PHP Core](php.md) |
| Ruby | [Ruby Core](ruby.md) |
| Perl | [Perl Core](perl.md) |
| Lua | [Lua Core](lua.md) |
| Dart | [Dart Core](dart.md) |
| Swift | [Swift Core](swift.md) |
| Julia | [Julia Core](julia.md) |
| R | [R Core](r.md) |
| D | [D Core](d.md) |
| Zig | [Zig Core](zig.md) |
| COBOL | [COBOL Core](cobol.md) |
| Fortran | [Fortran Core](fortran.md) |
| Elixir | [Elixir Core](elixir.md) |
| Erlang | [Erlang Core](erlang.md) |
| Nim | [Nim Core](nim.md) |
| V | [V Core](v.md) |
| Objective-C | [Objective-C Core](objective-c.md) |
| OCaml / Caml | [OCaml Core](ocaml.md) |
| MATLAB / Octave | [MATLAB/Octave Core](matlab.md) |
| Haskell | [Haskell Core](haskell.md) |
| Delphi / Free Pascal | [Delphi / Free Pascal Core](delphi.md) |

## 共享运行时示例与桥接

| 语言 | 形式 |
| --- | --- |
| JavaScript | [复用 TypeScript](javascript.md) |
| Kotlin | [复用 Java](kotlin.md) |
| Scala | [复用 Java](scala.md) |
| Groovy | [复用 Java](groovy.md) |
| Clojure | [复用 Java](clojure.md) |
| OpenCL | [复用 C 的计算示例](opencl.md) |
| Visual Basic | [复用 .NET](visual-basic.md) |
| F# | [复用 .NET](fsharp.md) |
| Shell | [运行时桥接](shell.md) |
| PowerShell | [运行时桥接](powershell.md) |
| Lisp | [SBCL 运行时桥接](lisp.md) |
| Tcl | [运行时桥接](tcl.md) |
| Prolog | [SWI-Prolog 运行时桥接](prolog.md) |

源码标签、包管理器发布、一致性测试和生产验证是不同状态。语言页面复用对应
源码 README，使安装、示例与限制保持一致。尚未翻译的语言说明会回退到英文。
