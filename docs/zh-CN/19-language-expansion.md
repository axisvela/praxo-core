# 语言扩展计划

**状态：**规划中，2026-10-25。本文评估 C#、Shell、PowerShell、Visual Basic、
R、PHP、Swift、Fortran、Lisp、Julia 与 Haskell，不新增 SDK。C 与 Rust 的
进度见[多语言路线图](18-multilingual-roadmap.md)。

各语言的规范状态见 `spec/languages.md`。

## 结论

不要手写十一个完整 Agent 循环。契约已经由五个实现验证：Go、Python、
TypeScript、Java 与 Rust。下一步采用**分层语言策略**：

- **原生核心 SDK**：生态能够承载完整契约的语言。
- **Wire 级 SDK**：需要生成或消费契约，但不拥有 Agent 循环的语言。
- **桥接绑定**：Shell、Visual Basic 与遗留语言，通过稳定进程边界调用维护中的
  运行时。

这样保持一份规范契约，避免十一个分叉的 Agent 循环。

## 分层模型

| 层 | 实现内容 | Agent 循环 | 契约门禁 |
| --- | --- | --- | --- |
| Core | 完整 SDK：model、tool、event、policy、memory、checkpoint、context、middleware、agent | 是 | 全部 11 组向量 |
| Wire | 序列化、toolcall、JSON Schema、插件 Manifest、事件、检查点信封 | 否 | 声明的 wire 与子集向量 |
| Bridge | 基于 CLI/stdio 或 HTTP 调用核心运行时 | 委托 | 桥接契约测试 |
| Sample | 使用另一 SDK 的语言示例（如 VB.NET 使用 C#） | 否 | 能编译 .NET 包 |

一个语言可以随着时间覆盖多个层。例如 Shell 只做桥接；PHP 可以先做 Wire，
再按需求发展 Core。

## 语言矩阵

| 语言 | 目标层 | 理由 | 建议 |
| --- | --- | --- | --- |
| C# | Core（.NET） | Agent/工具生态强，异步、JSON、打包成熟 | C 之后的下一原生 SDK |
| Visual Basic | Sample（.NET） | 与 C# 共享运行时与程序集 | 提供 VB 示例，不做第二套实现 |
| PowerShell | Bridge | 自动化与运维胶水，不适合承载运行时 | 包装 .NET CLI 或核心 CLI |
| Shell | Bridge | POSIX/Bash 胶水；策略、JSON、插件宿主风险高 | 通过 stdio/JSON 包装 CLI |
| PHP | Core（已交付） | Web 集成面大；同步生态 | 核心已随 `php/v0.1.0` 发布 |
| Swift | Core（已交付） | Apple 平台、结构化并发、`Codable` | 核心已随 `swift/v0.2.0` 发布 |
| Julia | Core（已交付） | 科学计算；JSON/HTTP 可用但 Agent 循环少见 | 核心已随 `julia/v0.2.0` 发布 |
| R | Core（已交付） | 统计与数据工作流；CRAN 生态 | 核心已随 `r/v0.2.0` 发布 |
| Haskell | Wire | 类型强，但 AI 工具需求较小 | Wire 级包 |
| Fortran | Bridge | 数值代码；不适合 Agent 运行时 | 仅在明确使用方时做 |
| Lisp | Bridge | 小众；S 表达式/JSON 桥接比完整移植便宜 | 仅在明确使用方时做 |

## 第二批候选

这些语言已列入计划但尚未实现。规则不变：没有明确使用方和维护者，不做新
核心循环。

| 语言 | 目标层 | 理由 | 建议 |
| --- | --- | --- | --- |
| JavaScript | Sample（TypeScript，已交付） | TypeScript 已可编译到 Node 与浏览器 | 示例位于 `javascript/`，不做第二套核心 |
| C++ | Core（已交付） | 原生系统与嵌入场景，工作量大 | 核心已随 `cpp/v0.1.0` 发布 |
| Dart | Core（已交付） | Flutter/Dart 异步、JSON、打包 | 核心已随 `dart/v0.1.0` 发布 |
| Ruby | Core（已交付） | Web 集成面大 | 核心已随 `ruby/v0.1.0` 发布 |
| Kotlin | Sample（JVM） | 使用 Java SDK | 仅 Kotlin 示例，不做独立核心 |
| Scala | Sample（JVM） | 使用 Java SDK | 仅 Scala 示例，不做独立核心 |
| MATLAB | Wire | 科学工作流；JSON/HTTP 可用 | Wire 级包 |
| Perl | Core（已交付） | CPAN、JSON、HTTP，适合遗留胶水 | 核心已随 `perl/v0.1.0` 发布 |
| Delphi | Wire / Bridge | Windows 企业集成 | 有使用方时做 Wire 或桥接 |
| OCaml / Caml | Wire | 类型强，Agent 需求较小 | Wire 级包 |
| Lua | Core（已交付） | 可嵌入脚本；需要嵌入式 JSON/HTTP 宿主 | 核心已随 `lua/v0.1.0` 发布 |
| Scratch | Bridge / 扩展 | 图形化环境，无原生 JSON/HTTP | 扩展桥接，需使用方 |
| COBOL | Core | 遗留企业批处理与流程集成 | 有明确使用方的 Core SDK |
| Prolog | Bridge | 逻辑与 CLI 工作流；无标准 HTTP/JSON 栈 | 有明确使用方时做桥接 |
| ABAP | Bridge | SAP 企业运行时 | 有使用方时做桥接 |

JavaScript、Kotlin 和 Scala 必须复用 TypeScript 或 Java 包，不能另写一套
契约实现。Scratch、Prolog 和 ABAP 不值得写原生循环。

## .NET 统一

C#、Visual Basic 与 PowerShell 可以共享一套 .NET 实现：

- `csharp/`（或 `dotnet/`）发布 `AxisVela.Praxo.Core`。
- VB.NET 使用同一个包；只增加示例与 API 说明，不分叉。
- PowerShell 包装 CLI 入口或加载 .NET 程序集。
- 目标 `net8.0`，公共表面尽量保持 CLS 兼容。

这样避免同一运行时写三遍。

## 桥接契约

桥接语言不得重新实现 Agent 循环。定义一个小型、版本化的进程契约：

```text
praxo run --session <id> --prompt <text> --json
praxo tool list --json
praxo event stream --json-lines
```

规则：

- JSON 写 stdout，诊断写 stderr。
- 流式输出每行一个 JSON 对象。
- 错误使用 `spec/wire/errors.json` 的共享错误码。
- 桥接声明其目标 `SPEC_VERSION`。
- Shell/PowerShell 包装器不得解析或改写工具调用标记，除非桥接契约明确暴露。

这是**进程边界**，不是 FFI。它保持 MIT 框架边界，避免 ABI/GC/线程耦合。

## Parity 与向量

当前 `spec/parity.md` 表按核心 SDK 设计。语言增多后，单一宽表不再可扩展。

计划结构：

```text
spec/
  languages.md               各语言层级与状态
  parity.md                  现有核心语言清单
  parity/
    csharp.md
    php.md
    swift.md
    julia.md
    r.md
    haskell.md
    bridge-shell.md
    bridge-powershell.md
```

规则：

- Core SDK 实现全部 11 组向量。
- Wire SDK 实现其声明的 wire 与子集向量。
- Bridge 实现桥接契约与错误码映射。
- Sample 不是契约实现，没有 parity 文件。
- parity linter 读取 `spec/languages.md`，只强制声明范围。

## 标签

| 产物 | Tag 形状 |
| --- | --- |
| C# | `csharp/v0.1.0` |
| PHP | `php/v0.1.0` |
| Swift | `swift/v0.1.0` |
| Julia | `julia/v0.1.0` |
| R | `r/v0.1.0` |
| Haskell | `haskell/v0.1.0` |
| Shell 桥接 | `shell/v0.1.0` |
| PowerShell 桥接 | `powershell/v0.1.0` |
| VB.NET 示例 | 不单独打 tag；随 .NET 包发布 |
| Fortran/Lisp | 仅在明确使用方时打 tag |

## 阶段

| 阶段 | 范围 | 退出条件 |
| --- | --- | --- |
| L0 | 稳定 Go/Python/TS/Java/Rust；通过工具链或 CI 完成 C | 现有门禁全绿 |
| L1 | .NET 核心（C#）、VB 示例、PowerShell 桥接 | 11 组向量 + .NET API 快照 |
| L2 | PHP core（已交付） | 11 组向量 + API 快照 |
| L3 | Swift core（已交付） | 11 组向量 + API 快照 |
| L4 | Julia、R core（已交付）；Haskell wire | 11 组向量 + API 快照 |
| L5 | Shell 桥接，Fortran/Lisp 视使用方 | 桥接契约测试 |
| L6 | C++、Ruby、Perl、Lua、COBOL core；JavaScript、Kotlin、Scala 示例 | 11 组向量 + API 快照 |
| L7 | Dart 按使用方转 core；MATLAB、OCaml wire；Delphi wire/桥接；Scratch、Prolog、ABAP 桥接 | 声明的 wire 或桥接门禁 |

内部投入估算位于本仓库之外。

## 不建议

- 并行写十一个完整实现。
- 用 FFI 把 Go/Rust 嵌入每个运行时。
- 在 Shell 语言中重新实现策略/路径约束或插件信任。
- 把 Visual Basic 当作 C# 之外的独立 SDK。
- Java SDK 已拥有契约时再做一套 JVM 核心。
- TypeScript 已是源实现时再做一套 JavaScript 核心。
- 没有明确使用方就做 Fortran/Lisp。
- 为 Scratch、Prolog 或 ABAP 写原生 Agent 循环。

## 决策记录

| ID | 决策 | 状态 |
| --- | --- | --- |
| L1 | 语言分层，不写十一个 Agent 循环 | 已接受 |
| L2 | C# 是下一个原生核心 SDK | 已接受 |
| L3 | Visual Basic 使用 .NET 包，不单独移植 | 已接受 |
| L4 | Shell 与 PowerShell 是桥接语言 | 已接受 |
| L5 | Fortran/Lisp 需要明确使用方 | 已接受 |
| L6 | 语言增多后 parity 迁移到按语言文件 | 提议中 |
| L7 | 第二批复用 TypeScript（JavaScript）与 Java（Kotlin/Scala） | 提议中 |
| L8 | C++、Ruby、Perl、Lua、COBOL 目标为 core | 提议中 |
| L9 | Scratch、Prolog、ABAP 为使用方门控桥接 | 提议中 |

## 相关文档

- [多语言 SDK 设计](17-multilingual-sdk.md)
- [多语言路线图](18-multilingual-roadmap.md)
- [兼容与弃用策略](16-compatibility-policy.md)
- [插件编写](10-plugin-authoring.md)
