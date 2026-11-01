# 语言实现支持政策

Go 是参考实现。[语言支持矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)
记录各语言的声明范围、源码标签与 CI 覆盖；该矩阵是实现状态的规范来源。

## Framework 目标

每个独立语言实现默认以共享核心契约的原生 Framework 实现为最终目标。
Wire 是中间阶段，不是永久的产品分类。只有明确记录的语言或运行时技术限制
确实阻止完整 Framework 实现时，才将 Wire 保留为最终范围。

工具链暂缺、开发尚未完成、需求较少或维护者尚未到位，都不等于语言不支持
Framework 行为。消费者和维护门槛决定何时启动工作，不改变最终目标。
最终目标也不代表当前已经可用、承诺交付日期、具备 Go 的全部可选集成或生产就绪。

## 当前阶段与交付形式

| 当前阶段或形式 | 含义 |
| --- | --- |
| Framework（`Core`） | 在声明的公开范围内提供原生框架行为，通过共享向量验证 |
| Wire | 正在向 Framework 演进的中间实现，当前只声明序列化与 wire 范围 |
| Bridge | 通过进程或 HTTP 边界调用受维护运行时 |
| Sample | 复用已有语言实现的示例，不是另一个独立运行时 |

实现类型不是稳定性等级，也不保证拥有 Go 的全部功能。采用前应阅读具体语言的
公开 API 和限制。
Bridge、Sample 描述运行时的接入方式，不证明其语言缺乏 Framework 实现能力；
共享运行时的语言可以复用宿主 Framework，而不是重复编写 Agent 循环。

## 行为能力层级

契约层级与行为能力层级回答不同问题。一个实现可以是契约层级的 `Core`，但其 agent 行为仍为部分覆盖，或者完全不在行为实验范围内。

| 行为层级 | 语言 | 当前目标 |
| --- | --- | --- |
| Agent-capable | Go、Python、TypeScript、Java、Rust、R、C# | 声明范围内包含原生 agent 循环；纳入十九个行为实验场景的目标集合 |
| Extended | C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua | 契约型或聚焦型实现；在有明确消费者和维护者的前提下逐场景推进行为覆盖 |
| Optional | 其他已声明实现 | 不在当前行为实验计划内；契约一致性不变，行为工作需有明确消费者和维护者 |

2026-11-01 的源码集覆盖十六个已接入语言：agent-capable 的 Go、Python、TypeScript、Java、Rust、R、C#，以及 extended 的 C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua。所有 agent-capable 语言和 C 均通过十九个场景；PHP 通过十八个，并行工具因无便携线程模型而不支持。其余扩展语言使用原生套件覆盖，没有场景测试的单元格保持 `unsupported`。逐单元格结果见[行为实验矩阵](behavior-lab-matrix.md)。

`85a9d7b` 上的 clean-SHA CI 运行为十六语言集报告了 205 passed、99 unsupported、无失败。矩阵由该报告生成。

`unsupported` 是明确记录的缺口，既不是失败，也不是通过。不要从契约成熟度 `complete` 推断完整行为对齐。

## 支持等级

成熟度记录声明范围的完成情况；支持等级记录谁负责响应问题和安全修复，两者独立。

| 等级 | 含义 | 不表示 |
| --- | --- | --- |
| `maintained` | 有明确维护者或团队、CI 和适用的安全修复 | 响应 SLA、完整 Go parity、所有 provider |
| `community` | 社区维护，尽力更新 | 响应时间、安全回移承诺 |
| `experimental` | 范围可能变化，无稳定性承诺 | 适合生产使用 |
| `deprecated` | 不再增加功能，提供迁移说明 | 未明确说明的移除日期 |

矩阵尚未为每一行发布支持等级列。在记录之前，不要从 `complete`、源码标签或包注册表可用性推断官方支持承诺。维护者确认后逐步补充。

记录支持等级时，应由负责的维护者或团队提供等级、CI job、最后验证的 tag 或 SHA，以及适用安全修复的范围。不要替他人指定支持等级，也不要把已合并的实现 PR 当作支持承诺。

## 版本与分发

- 核心、Core、适配器与契约独立版本化，每个 Core 声明其 `SPEC_VERSION`。
- 版本标签与成熟度相互独立：源码标签记录发布，成熟度记录声明范围的完成情况与验证状态。
- 源码标签不等于已发布到包管理器，应按语言页面中的安装或源码构建步骤操作。
- Python 已发布 `praxo-core==0.2.4` 到 PyPI；TypeScript 已从源码标签
  `typescript/v0.1.5` 发布 `@axisvela/praxo-core@0.1.5` 到 npm，带有 npm
  provenance，并采用 agent framework 优先的 README 和元数据。
- Java 已从源码标签 `java/v0.3.0` 在 Maven Central 发布
  `com.axisvela:praxo-core:0.3.0`，Maven groupId 为 `com.axisvela`，Java
  包名为 `com.axisvela.praxo`。较早的 `java/v0.2.3` 标签仍保留
  `io.axisvela.praxo`。
- PHP 源码标签 `php/v0.2.0` 包含流式运行、取消、SSE 校验、最终授权和生命周期清理。
  Packagist 包仍为 `axisvela/praxo-core==0.1.0`，来自独立发布仓库
  `axisvela/praxo-core-php`。并行工具执行仍不支持。
- Ruby 源码标签 `ruby/v0.3.0` 增加 middleware、最终工具 allowlist、重新授权、
  生命周期清理、取消、流式回调、原生 SSE parser、有限并行工具和按 run 隔离的调用上限。
  RubyGems 包仍为 `praxo-core==0.1.0`；干净项目已安装该 gem 并运行最小 agent。
- C++ 源码标签 `cpp/v0.3.0` 增加 middleware、最终工具 allowlist、重新授权、
  生命周期清理、取消、流式回调、原生 SSE parser、有限并行工具和按 run 隔离的调用上限。取消、流式、SSE、并行工具和 run-state isolation 仍不支持。
- Lua 源码标签 `lua/v0.3.0` 增加 middleware、最终工具 allowlist、重新授权、
  生命周期清理、取消、流式回调、原生 SSE parser 和调用方提供的批处理工具调度。
  LuaRocks 包仍为 `praxo-core==0.1.0-1`。本地 rock 构建和模块加载通过；
  registry 安装 smoke 待完成。
- C# 源码标签 `csharp/v0.2.0` 包含流式运行、取消、有限并行工具和 SSE 校验。
  NuGet 包仍为 `Praxo.Core==0.1.2`（源码标签 `csharp/v0.1.2`）；本地 .NET
  消费者安装尚未记录。
- D 已从独立发布仓库 `axisvela/praxo-core-d`（tag `v0.1.0`）在
  DUB/code.dlang.org 发布 `praxo-core==0.1.0`；主仓库保留源码标签
  `d/v0.1.0`。`dub fetch praxo-core` 已通过。
- Dart 已有源码标签 `dart/v0.1.1`，并在 publisher `axisvela.com` 下发布
  `praxo_core==0.1.1` 到 pub.dev。干净项目已安装该包、导入
  `package:praxo_core/praxo_core.dart` 并运行最小 agent。
- Rust 源码标签 `rust/v0.2.0` 包含全部 11 个向量组、原生测试、`tool.Gateway`、`jsonschema.Schema`、流式回调、取消、有限并行工具和 API 快照。crates.io 包仍为 `praxo-core==0.1.4`；干净临时项目安装该包后报告 `SDK_VERSION` `0.1.4` 和 `SPEC_VERSION` `0.2.0`。不包含 HTTP OpenAI adapter、VFS 或 plugin hosts。
- R 源码标签 `r/v0.4.0` 包含 policy、middleware、生命周期清理、取消、流式回调、SSE parser、有限并行工具和 API 快照。Unix 使用 `mclapply`，Windows 使用 PSOCK cluster；不声明包管理器发布。
- C 源码标签 `c/v0.5.0` 增加 policy 授权、有序 middleware、生命周期清理、
  最终工具 allowlist 检查、中途修改后的重新授权、取消、流式回调、SSE parser
  和有限并行工具。Unix 使用 pthread 与逐线程 arena；Windows 保持顺序执行。
- Fortran 源码标签 `fortran/v0.4.0` 包含全部 11 个向量组、原生测试、API 快照、
  PII/中间件，以及 policy 驱动的 middleware/生命周期授权。它不是包管理器发布；
  异步流不在声明范围，受限 JSON Schema 子集仍为部分完成。`0.3.0` 使用
  RE2/Unicode 取代 ASCII matcher，新增原生 C++ 库依赖；历史 `0.2.2` 标签仍保留
  无此原生依赖的实现。
- COBOL 已有源码标签 `cobol/v0.3.0`，包含全部 11 个向量组、原生与契约测试、调用方持有状态的 scoped registry 和 API 快照。它新增 middleware、生命周期、取消、流式、SSE 和调用方提供的批处理工具调度，行为覆盖达到 19/19；并行工具委托给批处理调度器，而不是原生线程。它不是包管理器发布；其余 Go 面大多为 partial，registry 无并发和 custom spec provider。
- Haskell 已有源码标签 `haskell/v0.2.0`，包含全部 11 个向量组、原生测试、API
  快照/parity 以及运行时/中间件辅助函数。未声明 Hackage 发布或生产就绪。
- Delphi/Free Pascal 已有源码标签 `delphi/v0.2.1`，在 Free Pascal 3.2.2 下通过
  全部 11 个向量组、原生测试和 API 快照/parity。商业 Delphi 编译器、其他目标
  平台和包管理器发布均未声明。
- MATLAB/Octave 已有源码标签 `matlab/v0.2.1`，在 Octave 下通过全部 11 个向量组、
  原生测试和 API 快照/parity。MATLAB 运行时、提供商适配器和包管理器发布均未声明。
- OCaml 已有源码标签 `ocaml/v0.2.0`，包含全部 11 个向量组、原生测试和 API
  快照/parity。原生 `ocamlopt` 编译、提供商适配器和包管理器发布均未声明。
- Elixir 源码标签 `elixir/v0.3.0` 增加 policy、middleware、最终工具 allowlist、
  重新授权、生命周期清理、取消、流式回调、原生 SSE parser、有限并行工具和按 run 隔离的调用上限。
  Hex 包仍为 `praxo_core==0.1.1`；HexDocs 尚未发布。
- Erlang 源码标签 `erlang/v0.3.0` 增加 policy、middleware、最终工具 allowlist、
  重新授权、生命周期清理、取消、流式回调、原生 SSE parser、有限并行工具和按 run
  隔离的调用上限。Hex 包仍为 `praxo_core_erlang==0.1.1`；提供商适配器、HTTP
  流式路径和生产就绪均未声明。
- Lisp 已有 SBCL 桥接的源码标签 `lisp/v0.1.0`，不提供原生 Lisp 循环；转发、UTF-8、
  错误和退出码检查已在本地和 Linux CI 通过。消费者细节与包管理器发布仍待完成。
- Tcl 已有桥接包装器的源码标签 `tcl/v0.1.0`，不提供原生 Tcl 循环；本地转发、UTF-8、
  错误和退出码测试已通过，远端 CI 与包管理器发布仍待完成。
- Prolog 已有 SWI-Prolog 桥接的源码标签 `prolog/v0.1.1`，不提供原生 Prolog 循环；
  转发、UTF-8、错误和退出码测试已通过。包管理器发布与生产就绪仍未声明。

## 功能边界

Python、TypeScript、Java、C# 包含流式路径与 OpenAI 兼容适配器，不能据此推断
其他语言也具备这些能力。`complete` 表示声明范围内的契约一致性；parity 清单仍可包含
该范围之外的功能 `partial`/`planned` 行。共享向量通过不等于 Go 全功能一致、真实提供商验证、
生产就绪或包仓库发布完成。

VFS、插件宿主、调度与可选集成应以对应 Core 的 README 和 API 参考为准。
贡献要求见 [Core 设计](../contributing/core-design.md)和
[语言支持规范](../contributing/language-policy.md)。
