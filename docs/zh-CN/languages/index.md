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
| Fortran | [Fortran 实现](fortran.md)，仍在开发中 |

## 共享运行时示例与桥接

| 语言 | 形式 |
| --- | --- |
| JavaScript | [复用 TypeScript](javascript.md) |
| Kotlin | [复用 Java](kotlin.md) |
| Scala | [复用 Java](scala.md) |
| Visual Basic | [复用 .NET](visual-basic.md) |
| Shell | [运行时桥接](shell.md) |
| PowerShell | [运行时桥接](powershell.md) |

## Wire 候选实现

[Haskell](haskell.md) 是以原生 Framework 为目标、尚未发布的 Wire 阶段实现，本地已通过
三个声明组的 24 个向量，当前不包含 Agent 循环。Linux、Windows CI 已通过，发布审查
仍待完成，不声明 Hackage 软件包、正式标签或交付日期。

[MATLAB / Octave](matlab.md) 是以原生 Framework 为目标、尚未发布的 Wire 阶段候选实现。
三个向量组已在本地 Octave 通过；MATLAB 和远端 CI 尚未验证。

源码标签、包管理器发布、一致性测试和生产验证是不同状态。语言页面复用对应
源码 README，使安装、示例与限制保持一致。尚未翻译的语言说明会回退到英文。
