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
| Agent-capable | Go、Python、TypeScript、Java、Rust、R、C# | 声明范围内包含原生 agent 循环；纳入二十个行为实验场景的目标集合 |
| Extended | C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua | 契约型或聚焦型实现；在有明确消费者和维护者的前提下逐场景推进行为覆盖 |
| Optional | 其他已声明实现 | 不在当前行为实验计划内；契约一致性不变，行为工作需有明确消费者和维护者 |

2026-11-02 的源码集覆盖十六个已接入语言：agent-capable 的 Go、Python、TypeScript、Java、Rust、R、C#，以及 extended 的 C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua。全部十六个已接入语言均覆盖二十个场景。COBOL、Lua、PHP 和 Fortran 的并行工具委托给调用方提供的批处理回调；这些情况下 Core 本身不创建线程。逐单元格结果见[行为实验矩阵](behavior-lab-matrix.md)。

`b6218e5` 上的 clean-tree CI 运行为十六语言集报告了 320 passed、0 unsupported、无失败。矩阵由该报告生成并链接同一 behavior job。

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

### 源码标签、注册表与消费者 smoke

三者是独立的声明：源码标签记录仓库发布，注册表版本记录包管理器可获取的版本，
消费者 smoke 记录仓库之外的安装与运行。不能用一个为另一个作证。下表注册表版本
已于 2026-11-05 对公开 registry 核对。

| 语言 | 源码标签 | 注册表版本 | 消费者安装 smoke |
| --- | --- | --- | --- |
| Python | `python/v0.3.2` | PyPI `praxo-core==0.3.2` 已发布 | 发布工作流构建并 smoke 测试 wheel/sdist；发布后消费者检查已在本地通过 |
| TypeScript | `typescript/v0.2.2` | npm `@axisvela/praxo-core@0.2.2` 已发布，并为 latest | 发布工作流构建并消费 tarball；`0.2.1` 发布后消费者检查已在本地通过 |
| Java | `java/v0.4.1` | Maven Central `com.axisvela:praxo-core:0.4.1` 已发布 | Central 已校验并发布；发布后消费者检查已在本地通过 |
| Rust | `rust/v0.3.0` | crates.io `praxo-core==0.3.0` 已发布；`0.1.4` 为历史版本 | 仅记录 `0.1.4`；`0.3.0` 未重跑 |
| C# | `csharp/v0.3.0` | NuGet `Praxo.Core==0.3.0` 已发布 | 未记录 |
| Elixir | `elixir/v0.4.1` | Hex `praxo_core==0.4.1` 已发布，包含可选 OpenAI-compatible adapter；`0.4.0`、`0.3.0`、`0.2.0` 为历史版本 | 已增加扩展 Starter；Hex `0.4.1` 在干净 Mix 项目中解析，allow/deny 本地通过 |
| Erlang | `erlang/v0.4.0` | Hex `praxo_core_erlang==0.4.0` 已发布；`0.3.1`、`0.2.0` 为历史版本 | `0.4.0` 未重跑；历史 `0.1.1` smoke |
| Ruby | `ruby/v0.4.1` | RubyGems `praxo-core==0.4.1` 已发布；`0.4.0`、`0.3.0`、`0.2.0` 为历史版本 | 已增加扩展 Starter；RubyGems `0.4.1` 已安装到干净 gem home，allow/deny 本地通过 |
| Lua | `lua/v0.4.1` | LuaRocks `praxo-core==0.4.1-1` 已发布，包含可选 OpenAI-compatible adapter；`0.4.0-1`、`0.3.0-1`、`0.2.0-1` 也已发布 | 已增加扩展 Starter；LuaRocks `0.4.1-1` 已安装到干净 tree，allow/deny 本地通过 |
| PHP | `php/v0.4.1` | Packagist `axisvela/praxo-core==0.4.1` 已发布，包含 Composer `autoload.files`；`0.4.0`、`0.3.0`、`0.2.0` 为历史版本 | 已增加扩展 Starter；Composer 安装已发布 `0.4.1` 后 Starter 无桥接本地通过 |
| Dart | `dart/v0.1.1` | pub.dev `praxo_core==0.1.1` | 已记录 `0.1.1` |
| Julia | `julia/v0.2.0` | General Registry PR #174826 已创建；mirror `0.2.0` | 未记录 |
| MATLAB | `matlab/v0.2.1` | MATLAB File Exchange `185166` 已发布 | 未记录 |
| Octave | `octave/v0.2.1` | Octave Packages PR #875 待合并；包归档已发布 | 未记录 |
| Perl | `perl/v0.1.1` | CPAN `Praxo-Core` 0.1.1 已上传；索引待完成 | 未记录 |
| PowerShell | `powershell/v0.2.0` | PowerShell Gallery `praxo-core-ps==0.2.0` 已发布 | 未记录 |
| Nim | `nim/v0.1.1` | nim-lang/packages PR #3600 待合并；nimpkgs 待重新抓取 | 未记录 |
| OCaml | `ocaml/v0.3.0` | opam-repository PR #31106 待合并；包 CI 已通过；opam-ci 待完成 | 未记录 |
| Haskell | `haskell/v0.2.0` | sdist 已发布；API 和手工上传均需 Hackage trustees 将账号加入 Uploaders | 未记录 |
| Delphi / Free Pascal | `delphi/v0.2.1` | OPM 资产已发布；维护者提交待完成 | 未记录 |

### 注册表相对代码的新旧状态

代码 manifest 是版本真源。只有当注册表 latest 与发布标签处的 manifest 一致时，
注册表才算最新。

| 语言 | 代码/manifest 版本 | 注册表 latest | 状态 |
| --- | --- | --- | --- |
| Python | `0.3.2` | PyPI `0.3.2` | 已最新 |
| TypeScript | `0.2.2` | npm `0.2.2` | 已最新 |
| Java | `0.4.1` | Maven Central `0.4.1` | 已最新 |
| Rust | `0.3.0` | crates.io `0.3.0` | 已最新 |
| C# | `0.3.0` | NuGet `0.3.0` | 已最新 |
| Elixir | `0.4.1` | Hex `0.4.1` | 已最新 |
| Erlang | `0.4.0` | Hex `0.4.0` | 已最新 |
| Ruby | `0.4.1` | RubyGems `0.4.1` | 已最新 |
| PHP | `0.4.1` | Packagist `0.4.1` | 已最新 |
| Lua | rockspec `0.4.1-1`；源码标签 `0.4.1` | LuaRocks `0.4.1-1` | 已最新 |
| Dart | `0.1.1` | pub.dev `0.1.1` | 已最新 |
| Julia | `0.2.0` | General Registry PR #174826 待合并 | 待完成 |
| MATLAB | `0.2.1` | File Exchange `185166` | 已最新 |
| Octave | `0.2.1` | Octave Packages PR #875 待合并 | 待完成 |
| Perl | `0.1.1` | CPAN 索引待完成 | 待完成 |
| PowerShell | `0.2.0` | PowerShell Gallery `0.2.0` | 已最新 |

不要从注册表安装只有源码标签的语言，也不要假设注册表包包含源码标签的最新行为。
语言页面是安装信息的唯一来源。

- Python 从源码标签 `python/v0.3.2` 发布 `praxo-core==0.3.2` 到 PyPI；TypeScript 从源码标签
  `typescript/v0.2.2` 发布 `@axisvela/praxo-core@0.2.2` 到 npm，带有 npm
  provenance，并采用 agent framework 优先的 README 和元数据。
- Java 源码标签 `java/v0.4.1` 增加人工审批中断决策，Maven groupId 为 `com.axisvela`，
  包名为 `com.axisvela.praxo`；Maven Central 已发布
  `com.axisvela:praxo-core:0.4.1`。较早的 `java/v0.2.3` 标签仍保留
  `io.axisvela.praxo`。
- PHP 源码标签 `php/v0.4.0` 在流式运行、取消、SSE 校验、最终授权、生命周期清理，
  以及通过 `batchToolInvoker` 提供的调用方协作式并行工具调度之上增加人工审批
  中断决策。Packagist 发布 `axisvela/praxo-core==0.4.0`，来自独立发布仓库
  `axisvela/praxo-core-php` 的 `v0.4.0` 标签；`v0.3.0` 和 `v0.2.0` 仍可用。
  Core 本身不创建线程。Composer 安装 smoke 尚未记录。
- Ruby 源码标签 `ruby/v0.4.0` 在 middleware、最终工具 allowlist、重新授权、
  生命周期清理、取消、流式回调、原生 SSE parser、有限并行工具和按 run 隔离的
  调用上限之上增加人工审批中断决策。RubyGems 已发布 `praxo-core==0.4.0`；
  `0.3.0` 和 `0.2.0` 仍可用。已记录的干净项目 smoke 仅覆盖 `0.1.0`。
- C++ 源码标签 `cpp/v0.4.0` 在 middleware、最终工具 allowlist、重新授权、
  生命周期清理、取消、流式回调、原生 SSE parser、有限并行工具和按 run 隔离的
  调用上限之上增加人工审批中断决策。
- Lua 源码标签 `lua/v0.4.0` 在 middleware、最终工具 allowlist、重新授权、
  生命周期清理、取消、流式回调、原生 SSE parser 和调用方提供的批处理工具调度
  之上增加人工审批中断决策。rock 修订 `0.4.0-1` 由
  `.github/workflows/lua-release.yml` 构建并发布；LuaRocks 同时保留
  `0.3.0-1` 和 `0.2.0-1`。工作流会在干净目录安装生成的 source rock 并运行
  安装后 smoke；registry 安装 smoke 尚未记录。
- C# 源码标签 `csharp/v0.3.0` 在流式运行、取消、有限并行工具和 SSE 校验之上增加人工审批中断决策。
  tag 工作流已发布 NuGet 包 `Praxo.Core==0.3.0`；本地 .NET 消费者安装尚未记录。
- D 已从独立发布仓库 `axisvela/praxo-core-d`（tag `v0.1.0`）在
  DUB/code.dlang.org 发布 `praxo-core==0.1.0`；主仓库保留源码标签
  `d/v0.1.0`。`dub fetch praxo-core` 已通过。
- Dart 已有源码标签 `dart/v0.1.1`，并在 publisher `axisvela.com` 下发布
  `praxo_core==0.1.1` 到 pub.dev。干净项目已安装该包、导入
  `package:praxo_core/praxo_core.dart` 并运行最小 agent。
- Rust 源码标签 `rust/v0.3.0` 在全部 11 个向量组、原生测试、`tool.Gateway`、`jsonschema.Schema`、流式回调、取消、有限并行工具和 API 快照之上增加人工审批中断决策。crates.io 已发布 `praxo-core==0.3.0`；已记录的干净临时项目安装 smoke 覆盖 `0.1.4`，报告 `SDK_VERSION` `0.1.4` 和 `SPEC_VERSION` `0.2.0`。不包含 HTTP OpenAI adapter、VFS 或 plugin hosts。
- R 源码标签 `r/v0.5.0` 在 policy、middleware、生命周期清理、取消、流式回调、SSE parser、有限并行工具和 API 快照之上增加人工审批中断决策。Unix 使用 `mclapply`，Windows 使用 PSOCK cluster。r-universe 从 `language/r` 发布 `praxocore==0.5.0`；CRAN 发布尚未声明，发布工作流执行 `R CMD build` 和 `R CMD check`。
- C 源码标签 `c/v0.6.0` 在 policy 授权、有序 middleware、生命周期清理、
  最终工具 allowlist 检查、中途修改后的重新授权、取消、流式回调、SSE parser
  和有限并行工具之上增加人工审批中断决策。Unix 使用 pthread 与逐线程 arena；
  Windows 保持顺序执行。
- Fortran 源码标签 `fortran/v0.6.0` 在全部 11 个向量组、原生测试、API 快照、
  PII/中间件、policy 驱动的 middleware/生命周期授权、取消、流式回调、原生 SSE
  parser 和调用方提供的批处理工具调度之上增加人工审批中断决策；HITL 运行使用
  顺序工具路径。它不是包管理器发布；异步 provider 流不在
  声明范围，受限 JSON Schema 子集仍为部分完成。`0.3.0` 使用 RE2/Unicode 取代
  ASCII matcher，新增原生 C++ 库依赖；历史 `0.2.2` 标签仍保留无此原生依赖的实现。
- COBOL 已有源码标签 `cobol/v0.4.0`，包含全部 11 个向量组、人工审批中断决策、原生与契约测试、调用方持有状态的 scoped registry 和 API 快照。它新增 middleware、生命周期、取消、流式、SSE 和调用方提供的批处理工具调度，行为覆盖达到 20/20；并行工具委托给批处理调度器，而不是原生线程。它不是包管理器发布；其余 Go 面大多为 partial，registry 无并发和 custom spec provider。
- Haskell 已有源码标签 `haskell/v0.2.0`，包含全部 11 个向量组、原生测试、API
  快照/parity 以及运行时/中间件辅助函数。Hackage 发布由
  `.github/workflows/haskell-release.yml` 准备；0.2.0 sdist 已发布到 `haskell/v0.2.0` GitHub release；API 和手工 candidate upload 都返回未授权上传者错误，需要 Hackage trustees 将账号加入 Uploaders。生产就绪尚未声明。
- Delphi/Free Pascal 已有源码标签 `delphi/v0.2.1`，在 Free Pascal 3.2.2 下通过
  全部 11 个向量组、原生测试和 API 快照/parity。OPM 资产已发布到 `delphi/v0.2.1` GitHub release，
  维护者提交待完成。商业 Delphi 编译器和其他目标平台未声明。
- MATLAB 已有源码标签 `matlab/v0.2.1`，包含全部 11 个向量组、原生测试和 API 快照/parity。
  MATLAB File Exchange `185166` 已发布；MATLAB 运行时和提供商适配器未声明。
- Octave 已有源码标签 `octave/v0.2.1`，在 GNU Octave 11.3.0 下通过全部 11 个向量组、
  原生测试和 API 快照/parity。它与 MATLAB 共享 `language/matlab-octave-core/+praxo`。
  包归档已发布到 `octave/v0.2.1` GitHub release，Octave Packages PR #875 待合并。
- OCaml 已有源码标签 `ocaml/v0.3.0`，包含全部 11 个向量组、原生测试和 API
  快照/parity。split 包仓库 `axisvela/praxo-core-ocaml` 发布 opam 包
  `praxo-core` 0.3.0（模块 `Praxo_core`）；opam-repository PR #31106 待合并。原生 `ocamlopt` 编译和
  提供商适配器未声明。
- Elixir 源码标签 `elixir/v0.4.0` 在 policy、middleware、最终工具 allowlist、
  重新授权、生命周期清理、取消、流式回调、原生 SSE parser、有限并行工具和按 run
  隔离的调用上限之上增加人工审批中断决策。Hex 已发布 `praxo_core==0.4.0`；
  `0.3.0` 和 `0.2.0` 仍可用。HexDocs 已发布：
  <https://praxo-core.hexdocs.pm/0.4.0/>。
- Erlang 源码标签 `erlang/v0.4.0` 在 policy、middleware、最终工具 allowlist、
  重新授权、生命周期清理、取消、流式回调、原生 SSE parser、有限并行工具和按 run
  隔离的调用上限之上增加人工审批中断决策。Hex 已发布
  `praxo_core_erlang==0.4.0`；`0.3.1` 和 `0.2.0` 仍可用。提供商适配器、HTTP
  流式路径和生产就绪均未声明。
- Lisp 已有 SBCL 桥接的源码标签 `lisp/v0.1.0`，不提供原生 Lisp 循环；转发、UTF-8、
  错误和退出码检查已在本地和 Linux CI 通过。消费者细节与包管理器发布仍待完成。
- Tcl 已有桥接包装器的源码标签 `tcl/v0.1.0`，不提供原生 Tcl 循环；本地转发、UTF-8、
  错误和退出码测试已通过，远端 CI 与包管理器发布仍待完成。
- Prolog 已有 SWI-Prolog 桥接的源码标签 `prolog/v0.1.1`，不提供原生 Prolog 循环；
  转发、UTF-8、错误和退出码测试已通过。包管理器发布与生产就绪仍未声明。

## 功能边界

Python、TypeScript、Java、Rust、R、C# 包含人工审批中断决策；Python、TypeScript、
Java、C# 还包含流式路径与 OpenAI 兼容适配器，不能据此推断其他语言也具备这些能力。`complete` 表示声明范围内的契约一致性；parity 清单仍可包含
该范围之外的功能 `partial`/`planned` 行。共享向量通过不等于 Go 全功能一致、真实提供商验证、
生产就绪或包仓库发布完成。

VFS、插件宿主、调度与可选集成应以对应 Core 的 README 和 API 参考为准。
贡献要求见 [Core 设计](../contributing/core-design.md)和
[语言支持规范](../contributing/language-policy.md)。
