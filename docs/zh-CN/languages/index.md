# 语言实现

先选择语言，再按对应页面安装或从源码构建。Go 是参考实现；共享契约不代表
所有语言都有 Go 的全部功能。请先阅读[支持政策](support.md)与
[规范支持矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)。

[查看全部语言与当前状态](matrix.md){ .md-button }

包名、版本、发布地址和待发布状态见[注册表发布状态](registry-status.md)。
独立仓库见[各语言独立仓库](repositories.md)，其中索引了所有已实现语言的专用仓库。
Model、MCP 与 Harmovela 覆盖见[适配器状态](adapter-status.md)。

每个条目使用独立的 docs/languages/<language>/ 目录，用于 Core 页面以及后续示例、适配器说明和发布页面。

## 今天能构建什么

按需要的成果选择分组，再核对语言页面、包注册表和示例 README。这些是构建导向路径，
不是支持层级或生产就绪声明。

| 路径 | 语言 | 能获得什么 | 边界 |
| --- | --- | --- | --- |
| 发布包治理 Starter | Go、Python、TypeScript、Java | 从发布包安装或构建，运行确定性模型，并通过 allow/deny 与治理负向检查 | 每种语言对应一个记录的包版本；不是采用或生产证据 |
| 发布包 allow/deny Starter | Ruby、PHP、Elixir、Lua | 发布包、确定性 allow/deny 和源码示例 | 消费者 Starter；治理负向矩阵仍只覆盖四个试点语言 |
| 发布包或源码发布并可运行示例 | Rust、C#、R、Dart、Erlang、Haskell、Perl、PowerShell | Registry 或 r-universe 发布，以及 HITL、Streaming、Checkpoint 等确定性示例 | Registry 版本可能落后源码标签；核对发布状态和示例深度 |
| 源码 Core 与确定性示例 | C、C++、Fortran、COBOL、Julia、MATLAB/Octave、Swift、D、Nim、V、Zig、OCaml、Objective-C、Delphi / Free Pascal | 从源码构建并运行确定性示例，包括 HITL 与 Session Checkpoint | 部分 Registry 提交仍在进行；平台和工具链限制按语言记录 |
| 共享运行时 Sample | JavaScript、Kotlin、Scala、Groovy、Clojure、Visual Basic、F# | 基于 TypeScript、Java 或 .NET Core 的使用示例 | 不是独立运行时或独立版本化包 |
| Bridge | Shell、Lisp、Tcl、Prolog | 基于维护中运行时的进程或 CLI Bridge | 没有本地 Agent 循环或委派接口 |

源码入口不等于执行证明。哪些主题真正调用 Core、哪些只是机制检查，见
[示例深度审计](../getting-started/language-coverage.md)，实际运行记录见
[验证证据](../project/verification-evidence.md)。

选定实现的可复现一致性证据见[兼容性实验](compatibility-lab.md)，跨语言 agent 行为场景见[行为实验](behavior-lab.md)。行为证据不存在能力层级，见[行为证据](support.md#行为证据)。

具备原生实现能力的独立语言默认以 Framework 为最终目标。处于 Wire 阶段的实现
当前尚不提供完整 Framework；仅有明确的技术限制时才以 Wire 为最终范围。当前能力
和最终目标的区别见[支持政策](support.md)。

## 生态分类

下列分类仅用于发现和选择，不代表支持阶段、发布门禁或优先级排序。一种语言可以同时属于多个分类。契约范围仍以[语言矩阵](matrix.md)为准，行为证据与限制以[支持政策](support.md)为准。

| 分类 | 语言 | 说明 |
| --- | --- | --- |
| 流行 | Go、Python、TypeScript / JavaScript、Java、C#、C、C++、Rust、PHP、Ruby、Swift、Kotlin、Scala | 生态和工具链较广；JavaScript、Kotlin、Scala 是基于其他 Core 的示例 |
| 新兴 | Zig、V、Nim、Swift、Dart、Kotlin、Solidity（计划中）、Mojo（计划中） | 较新或快速演进的生态；计划中条目尚不可用 |
| 遗留 | COBOL、Fortran、Ada（计划中）、Delphi / Free Pascal、Objective-C、Perl、Visual Basic、VBScript（计划中）、FoxPro（计划中）、Classic Visual Basic（计划中）、J#（需消费者） | 维护和集成路径；计划中或被门禁的条目不是正式发布 |
| 数据 | R、Julia、MATLAB、Octave、Python、Fortran | 分析、数值和 HPC 工作流 |
| AI | Python、R、Julia、Mojo（计划中）、C++、Rust | 模型集成和推理工具；Core 不提供模型或托管服务 |
| 本地 / 嵌入式 | C、C++、Rust、Zig、D、Ada（计划中）、Assembly（需消费者）、OpenCL（示例） | 原生运行时、设备和计算边界 |
| 脚本 / 自动化 | Python、JavaScript、Ruby、Perl、PHP、Lua、Shell、PowerShell、Tcl | 胶水、运维和本地自动化 |
| 冷门 / 领域特定 | Haskell、OCaml、F#、Clojure、Lisp、Prolog、Erlang、Elixir、Tcl、Zig、V、Nim | 生态专注、维护者较少的语言 |
| 候补 / 计划 | Ada、Mojo、Solidity、VBScript、FoxPro、Q、Assembly、Scratch、ABAP、J#（需消费者） | 开始实现前需要具名消费者、维护者或兼容运行时 |

用分类选择可能的起步语言，然后核对语言页面、包注册表和示例 README。分类不代表生产就绪或完整 Go 功能对齐。

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
| MATLAB | [MATLAB Core](matlab/index.md) |
| Octave | [Octave Core](octave/index.md) |
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
