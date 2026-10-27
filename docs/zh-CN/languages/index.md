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
| Python | [Python SDK](python.md) |
| TypeScript | [TypeScript SDK](typescript.md) |
| Java | [Java SDK](java.md) |
| Rust | [Rust SDK](rust.md) |
| C | [C SDK](c.md)，当前公开 API 为 wire 级别 |
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
| Fortran | [Fortran 实现](fortran.md) |
| Elixir | [Elixir SDK](elixir.md) |
| Erlang | [Erlang SDK](erlang.md) |
| Nim | [Nim SDK](nim.md) |
| V | [V SDK](v.md) |
| Objective-C | [Objective-C SDK](objective-c.md) |
| OCaml / Caml | [OCaml SDK](ocaml.md) |

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

## Wire 实现

[Haskell](haskell.md) 已有源码标签 `haskell/v0.1.0`，以原生 Framework 为目标。本地已通过
三个 Wire 向量组和实验性 Agent 循环向量；新循环的远端 CI 仍待完成。不声明 Hackage
软件包或交付日期。

[MATLAB / Octave](matlab.md) 已有源码标签 `matlab/v0.1.0`，以原生 Framework 为目标。
三个 Wire 向量组和 Agent 循环向量已在本地 Octave 通过；MATLAB 和新循环的远端 CI 尚未验证。

[Delphi / Free Pascal](delphi.md) 已有源码标签 `delphi/v0.1.0`，以原生 Framework 为目标。
三个 Wire 向量组和 Agent 循环向量已在本地 Free Pascal 3.2.2（Windows i386）通过；新循环的远端 CI 和 Delphi 编译器仍待验证。

源码标签、包管理器发布、一致性测试和生产验证是不同状态。语言页面复用对应
源码 README，使安装、示例与限制保持一致。尚未翻译的语言说明会回退到英文。
