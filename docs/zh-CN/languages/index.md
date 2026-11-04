# 语言实现

先选择语言，再按对应页面安装或从源码构建。Go 是参考实现；共享契约不代表
所有语言都有 Go 的全部功能。请先阅读[支持政策](support.md)与
[规范支持矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)。

[查看全部语言与当前状态](matrix.md){ .md-button }

每个条目使用独立的 docs/languages/<language>/ 目录，用于 Core 页面以及后续示例、适配器说明和发布页面。

选定实现的可复现一致性证据见[兼容性实验](compatibility-lab.md)，跨语言 agent 行为场景见[行为实验](behavior-lab.md)。行为覆盖分为 agent-capable、extended 和 optional 三个层级，见[支持政策](support.md)。

具备原生实现能力的独立语言默认以 Framework 为最终目标。处于 Wire 阶段的实现
当前尚不提供完整 Framework；仅有明确的技术限制时才以 Wire 为最终范围。当前能力
和最终目标的区别见[支持政策](support.md)。

## 原生实现

| 语言 | 使用入口 |
| --- | --- |
| Go | [安装与快速开始](go/index.md) |
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
| MATLAB / Octave | [MATLAB/Octave Core](matlab/index.md) |
| Haskell | [Haskell Core](haskell/index.md) |
| Delphi / Free Pascal | [Delphi / Free Pascal Core](delphi/index.md) |

## 共享运行时示例与桥接

| 语言 | 形式 |
| --- | --- |
| JavaScript | [复用 TypeScript](javascript/index.md) |
| Kotlin | [复用 Java](kotlin/index.md) |
| Scala | [复用 Java](scala/index.md) |
| Groovy | [复用 Java](groovy/index.md) |
| Clojure | [复用 Java](clojure/index.md) |
| OpenCL | [复用 C 的计算示例](opencl/index.md) |
| Visual Basic | [复用 .NET](visual-basic/index.md) |
| F# | [复用 .NET](fsharp/index.md) |
| Shell | [运行时桥接](shell/index.md) |
| PowerShell | [PowerShell Core](powershell/index.md) |
| Lisp | [SBCL 运行时桥接](lisp/index.md) |
| Tcl | [运行时桥接](tcl/index.md) |
| Prolog | [SWI-Prolog 运行时桥接](prolog/index.md) |

源码标签、包管理器发布、一致性测试和生产验证是不同状态。语言页面复用对应
源码 README，使安装、示例与限制保持一致。尚未翻译的语言说明会回退到英文。
