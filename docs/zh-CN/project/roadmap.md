# 公开路线图

[100 个智能体场景目录](../getting-started/agent-scenarios.md) 将十六大领域映射到有界切片与
全部 31 个现有 Core 条目的候选分配。这是规划覆盖，不是 100 个应用已实现或跨语言 parity
保证。Ruby SE-07 FinOps 切片本地源码测试及 `dfdfd558` 教程 CI 通过，无云写入或真实
模型验证。

当前核心版本为 `2.10.0`。

本路线图按开发者成果组织：判断是否适用、跑出有用结果、完成真实原型、嵌入应用，
最后再加固具体集成。它不是交付排期、产品路线图，也不表示所有语言实现都支持每项能力。

## 下一阶段方向

**规划更新：2026-11-13。** 当前首要目标是缩短从发现框架到做出有用项目的路径。
新用户不需要先理解完整规范、证据分类、跨语言矩阵或高级执行 Profile，才能开始开发。

**规划更新：2026-11-16。** 下一阶段重点是证据深度和第一条可用路径，而不是增加语言
条目。第一条路径是五分钟嵌入，治理验收是第二步。公开声明区分契约完成、Adapter 可用
和集成已验证。Go 源码提交 `73da5139` 已将记忆召回移出 system 角色，`2.9.0` 与 `2.10.0`
已包含该修复；`2.8.0` 仍使用旧角色。该修复不防止所有提示注入，也不代表全部 SDK 具有相同行为。
工具参数在编辑后仍重新授权。

**规划更新：2026-11-20。** `2.10.0` 记录各声明语言的 provider SSE streaming
和进程插件宿主。C/C++ 的 vcpkg、Conan Center 和 xmake 配方已准备并提交上游；
上游 PR 不等于 registry 发布或安装证据。分发工作不追求语言数量：外部项目完成
安装并跑通 allow/deny 后，才算采用。

**规划更新：2026-11-22。** 文档现在统一为“阅读导览”中的一张任务到路径表；语言入口
按开发者今天能构建什么分组；示例目录已有第一轮源码深度审计；消费者测试模板已加入
各语言起点。这些只关闭内部文档缺口，不关闭外部证据缺口。独立五分钟计时、托管端点
验证、外部消费者选定路径和 Registry 安装验证仍然开放，分别记录在
[#30](https://github.com/axisvela/praxo-core/issues/30)、
[#31](https://github.com/axisvela/praxo-core/issues/31)、
[#32](https://github.com/axisvela/praxo-core/issues/32) 和
[#33](https://github.com/axisvela/praxo-core/issues/33)。仓库自维护 fixture 不能替代
外部证据。

PRAXO-CORE 继续定位为**可治理、可嵌入的 Agent 执行框架**。路线图优先完整可运行的
应用路径和清晰集成边界，不追求语言、Adapter、Profile 或测试数量。既有系统和受约束
运行环境是主要集成目标；新增语言 Kernel 或 Adapter 仍需要明确消费者、维护者和真实
部署路径。

### 规划原则

**规划更新：2026-11-25。** 基础场景入口已完成一轮交付；[总目录](../getting-started/tutorial-catalog.md)
区分相关切片与完整应用。教程 CI 在 `dfdfd558`、运行 `45537631891` 通过，这是绑定 revision
的 fixture 证据，不是外部采用。下一步以生态原生参考应用为主线，选型到验证测量服务于应用路径，
不是另一轮语言数量扩张。发现材料已具备，但对无辅助选型的影响仍只有既有受限试点记录。

**规划更新：2026-11-24（基础入口阶段）。** 场景广度不能证明语言适配性。当时优先批量完成
基础场景入口、推广和吸引用户，再根据使用反馈优化。每个入口保持准确边界，
按[语言选择门槛](../getting-started/tutorial-plan.md#language-selection-gate)
评估现有映射。优先提供准确的选型说明和可复现的起点。宿主集成的深化由明确消费者
或具体使用反馈驱动，不要求批量深化尚无使用需求的教程。
简短诚实的选型说明即可支持基础示例发布，不把深度生态集成设为前置条件。
通用脚本化 fixture 只作为 Core 集成示例，不证明该语言更适合某个行业任务。
选择依据必须区分既有运行时约束与已演示的生态能力，并说明何时不应选择该运行时。

- 先让程序产生有用结果，再解释底层契约。
- 从已发布包和常见本地或托管模型端点开始。
- 首次路径只保留一个最小拒绝检查；完整矩阵和故障演练后移到加固阶段。
- 新能力先使用示例、配方和可选 Adapter，不先扩大 Core 公共 API。
- 只有真实消费者证明可复用缺口后，才增加共享 API。
- 凭据、身份、持久状态、隔离和产品数据始终由嵌入应用负责。

## 语言范围

本路线图适用于整个 PRAXO-CORE 家族，而不只针对 Go 参考实现。Go 定义规范参考行为，
各语言 Core 以独立版本和符合本语言习惯的 API 发布。以下阶段描述共同的开发者路径；
具体语言可用性、安装方式和功能覆盖以[语言实现矩阵](../languages/index.md)和
[支持政策](../languages/support.md)为准。

| 范围 | 语言 | 路线图要求 |
| --- | --- | --- |
| 参考实现 | Go | 定义共享行为并引领参考示例 |
| Agent-capable Core | Python、TypeScript、Java、Rust、R、C# | 共享采用阶段，并在可行时提供可运行的 Provider、Tool 和集成路径 |
| Extended Core | C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua | 在消费者和维护者需求充分时提供采用路径；高级能力可保持 Go 优先 |
| 其他已声明实现 | 矩阵中的其他语言，以及 Bridge 和 Sample 条目 | 使用对应语言文档并明确差距；不承诺每个示例或功能都可用 |

路线图不要求所有语言同时发布所有示例，但要求面向用户的路径明确标注目标语言和包，
不能把仅在 Go 中成立的行为表述为跨语言保证。语言数量不是目标：`complete` 只表示
契约完成；Adapter 和集成层见[适配器状态](../languages/adapter-status.md)。

这些是技术覆盖分组，不是投入优先级或支持 SLA。消费者需求可以使任一分组中的实现
获得优先投入，但不会改变其声明能力或证据等级。

长尾语言工作按市场实验评估，而不是按语言数量扩张。首批候选是用于现有 Windows
自动化的 PowerShell、用于仿真工作流的 Fortran、用于既有业务系统的 COBOL，以及
用于既有应用的 Delphi / Free Pascal。每项都需要明确消费者，并证明嵌入式 Core
比外部编排更适合真实任务。契约通过或包发布不等于采用。

### COBOL 批处理异常审阅

- 保持主批处理确定性，且不等待审阅完成。先运行[批处理异常审阅示例](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/batch-exception-review)，
  检查 worker 慢响应或不可用时，正常输出不变、异常记录保留、审阅不提交业务写入。
- 有具名使用方后，再比较使用 Core 的独立 COBOL 审阅步骤与不在主批嵌入 Core 的外部
  worker。记录批窗口是否达标、异常积压及恢复情况、接入成本。除非将策略和工具逻辑留在
  COBOL 能解决已证实的问题，否则优先外部 worker。示例不是生产证据。

## 采用路径

| 阶段 | 开发者成果 | 当前状态 | 下一项成果 |
| --- | --- | --- | --- |
| 0. 判断 | 知道 Core 是否适合，以及该选择哪种语言和路径 | 已有概览、对比、非目标说明，以及“阅读导览”中唯一一张任务到路径表；首页与概览均链接到该表。语言入口按今天能构建什么分组 | 在外部引导中使用该表并记录断点；保持语言入口与 Registry 状态一致 |
| 1. 运行 | 安装发布包、连接模型、注册一个工具并得到有用结果 | 已有发布包确定性 Starter 和真实模型示例；五分钟完成尚未经过独立计时。注册表状态单独记录在语言支持页面。live-model 指南已覆盖端点、模型 ID、凭据、超时、Tool Schema 和平台排错。Go、Python、TypeScript、C# 与 Rust 已记录本地 Ollama 工具调用（C# 与 Rust 通过构建后的二进制），但没有托管端点记录；本地 Java JVM 仍受阻 | 分别记录独立确定性嵌入和真实端点完成情况；托管端点见 [#31](https://github.com/axisvela/praxo-core/issues/31)，独立计时见 [#30](https://github.com/axisvela/praxo-core/issues/30) |
| 2. 原型 | 完成一个包含工具、Streaming、结构化输出、MCP、Workspace 或 Telemetry 的连贯本地应用 | 十三个主题在三十一种语言中有源码入口，目录已按任务分组；第一轮源码深度审计已区分 Core 引用、机制检查和传输中立 Handler，但不证明实际执行。端到端原型教程现包括 Go Workspace Agent 和 Python 结构化输出应用；其他示例多为集成检查 | 将源码深度审计转为消费者选定路径的运行记录；外部验证见 [#32](https://github.com/axisvela/praxo-core/issues/32) |
| 3. 嵌入 | 将 Core 接入现有服务，由应用管理身份、策略、持久化、事件和退出 | 已有厂商中立的 Go/Python/TypeScript/C# 服务和认证身份/策略服务；Go、Python、TypeScript、C#、Ruby、PHP 与 Rust 支持带 provider discovery 的 OIDC/JWKS；Java 示例已在 Linux CI 通过，本地 Windows JVM 仍受阻；31 个已声明实现中有 30 个提供源码级 RFC 7662 introspection 与 RFC 7009 撤销，其中 29 个本地运行验证（28 个原生运行时 + Octave 覆盖 MATLAB/Octave 共享模块），原生 MATLAB 未验证，COBOL 仅记录边界；另有 Python 可选外部策略决策服务、已验证身份与持久 Checkpoint 变体、分档清单，以及连接消息历史、allowlist Store 和操作状态的 Checkpoint 续跑指南 | 将 OIDC/外部身份模式扩展到更多 SDK，为消费者选定的语言补齐 registry 发布，单独记录原生 MATLAB，并为真实消费者验证 Checkpoint Store |
| 4. 加固 | 让具体集成可升级、可失败、可取消、可恢复 | 已有负向、升级、隔离和恢复资产；Go 记忆角色修复已在 `2.9.0` 发布，重试风险测试有本地确定性覆盖。源码审计未发现其他 SDK Agent 主路径或 Bridge `run`/`event stream` 路径的自动召回。消费者测试模板已加入两轮记忆信任、未知效果重试/对账检查和各语言起点；已对 10 个仓库自维护 fixture 中的 9 个完成运行，本地 Java 超时，这些都不是外部消费者 | 把模板应用到外部消费者；仓库 fixture 不能替代。见 [#32](https://github.com/axisvela/praxo-core/issues/32) |
| 5. 扩展 | 在需要时采用 Plugin、委派、长时操作、Workspace Provider 或具身集成 | 应用级委派示例覆盖 Go、Python、TypeScript、Java、C# 和 Rust；Go 参考示例覆盖长时操作、Workspace 和 Plugin | 在宣称受治理委派前，先实现父子策略、工具范围、预算和深度收窄 |

这些阶段表示推荐采用顺序，不是发布门禁，也不要求所有语言同步推进。

## 阶段 0：判断 Core 是否适合

### 开发者成果

开发者可以在几分钟内回答：

- 嵌入式模型/工具循环是否适合当前任务？
- 应选择哪种语言和 Starter？
- 哪些职责仍由自己的应用承担？

### 立即开始

- [阅读导览](../getting-started/index.md)
- [概览](../getting-started/overview.md)
- [何时不应选择 PRAXO-CORE](../getting-started/when-not-to-use.md)
- [语言实现](../languages/index.md)
- [语言支持与分发](../languages/support.md)
- [框架对比](comparison.md)

### 下一步工作

- 已在“阅读导览”中统一一张“任务到路径”表；后续在外部引导中验证并记录断点。
- 已分开“体验框架”“验证包”“嵌入应用”“加固部署”和“扩展”路径。
- 已按“能构建什么”分组语言入口；后续与 Registry 状态保持同步。
- 让每个包的说明明确归类为 AI Agent 框架，而不是 HTTP Agent 或托管服务，并保持
  Coding Agent 版本表与发布元数据一致。

[契约与证据状态](contract-status.md)继续保留，但不是第一个项目的前置阅读。

## 阶段 1：跑出有用 Agent

### 开发者成果

从空目录开始，安装已发布包，连接 Ollama 或 OpenAI-compatible 端点，注册一个低风险
工具，并看到模型响应或工具结果。完成时间是目标，不是已测量结果：

- 五分钟：工具链已安装后完成确定性嵌入，不要求真实模型或 API Key。
- 15-30 分钟：端点和凭据已就绪后完成真实工具调用；模型下载和账号准备另行记录。

从文档安装命令开始计时，到预期结果出现为止，记录环境、失败、修复与作者协助。
治理验收仍是独立后续路径。

首次路径只检查三件事：

1. 应用能够启动；
2. 工具能够成功调用；
3. 一次明确拒绝不产生工具副作用。

它不要求完整治理负向矩阵、跨版本升级套件、Behavior Lab 或兼容性报告。

### 立即开始

- [快速开始](../getting-started/quickstart.md)
- [真实模型 Golden Path](../getting-started/live-model-golden-path.md)
- [Go](../getting-started/consumer-go.md)、
  [Python](../getting-started/consumer-python.md)、
  [TypeScript](../getting-started/consumer-typescript.md)、
  [Java](../getting-started/consumer-java.md) 发布包 Starter
- [Ruby](../getting-started/consumer-ruby.md)、
  [PHP](../getting-started/consumer-php.md)、
  [Elixir](../getting-started/consumer-elixir.md)、
  [Lua](../getting-started/consumer-lua.md) 扩展语言 Starter
- 各语言已提供的 [OpenAI-compatible Adapter](../reference/openai-compatible-adapter.md)

### 下一步工作

- 对 Ollama 和至少一个托管 OpenAI-compatible 端点验证四语言真实模型示例，再扩展到
  其他有维护者的语言。
- 为主要 SDK 提供从确定性 Starter 到真实模型端点的直接后续路径，并给出对应语言的
  安装方式和代码。
- 记录预期输出，以及端点地址、模型名、凭据、超时、Tool Schema 和平台相关环境变量
  的简短排错说明。

## 阶段 2：完成真实原型

按语言特点构建应用教程，复用公开 MIT 仓库 `axisvela/agent-tutorial-services`
中的合成业务服务。先实现有资源范围的订单查询和处理草稿，再按验证结果增加 Java
企业订单、Python/C# 服务台、PowerShell/Perl 运维、COBOL 批处理审阅、Julia/R/Octave
分析、Lua 宿主嵌入、Rust 网关适配器 fixture、Zig 网关健康 fixture 以及 C/C++ 设备场景。
业务 API 不进入 Core 或 `spec/`；
必须支持本地运行，公共托管可选。维护者教程不等于独立消费者证据。

新增应用教程位于 `language/<language>/Tutorial/`，与 `examples/` 并列；已有机制
示例保留原路径。

首个本地切片已实现 HTTP 订单服务和原生 Python、TypeScript 客户端，覆盖仅创建草稿的
成功路径、Agent 策略/服务端拒绝和依赖失败。这是源码/本地 fixture 证据，不是托管
服务、完整企业 Web 教程或外部采用。

Java 的 `Tutorial/order-review/` 已加入 CLI、loopback Web 入口和 JUnit 契约测试；
本地 JVM 验证受阻，但 Linux CI 已在 `3c2063f9`（run `45031868787`）通过编译和
mock Agent/Web 测试。TypeScript 教程已安装自身固定版本依赖。

教学后端现已公开，原演示仓库保持私有。Core CI 固定引用公开后端 `8b7820e` 执行完整
原生客户端门禁，不需要私有凭据。完整 Python/TypeScript/Java CLI 集成已在 Core
`8b0593bb`（run `45033109188`）通过，使用发布包和确定性模型。此前的私有门禁仍是
历史跳过记录，不是通过；两者都不等于独立采用或真实 Provider 验证。

C# 已有本地验证的 ASP.NET Core 服务台教程，包含固定订单路由与原生 Core CLI；公开
集成测试加入真实 Web 鉴权、草稿重放和依赖失败检查。四语言 CLI 与 C# Web 集成已在
`ae953050`（run `45034303513`）、后端 `cd08b09` 的 CI 通过；不声称真实模型、生产
身份或公共部署验证。

PowerShell 的 `Tutorial/windows-diagnostics/` 通过共享 C# Core 增加固定只读 Windows
服务/磁盘检查。本地 PowerShell 7.7.0 测试 4/4 通过，托管 Windows CI 也已在
`5afe6e35`（run `45036962205`）通过 C# Core 构建和全部四项源码模式检查。它不提供
修复、远程主机、任意 Shell 命令或真实模型路径。
Perl 的 `Tutorial/log-triage/` 增加原生运维路径：固定 fixture 日志、严重级别报告、
策略拒绝和依赖失败。本地 Perl 5.40.3 检查通过，Linux CI 也已在 `3b5edcc7`
（run `45038008192`）通过。它不读取任意
路径、不执行 Shell、不发送告警、不调用真实模型。
R 的 `Tutorial/data-quality/` 通过原生 R Core 计算固定数据框统计并返回封装工具计算值的
报告。本地 R 4.6.1 检查通过，Linux CI 也已在 `e89c9037`（run `45039622807`）通过。
它不读取任意文件、不执行 SQL/Shell、不安装包、不调用真实模型。
R 的 `Tutorial/marketing-segmentation/` 把固定八客户 fixture 分成四个分群，计算原生
分群均值（`vip` = `825`），选出最高价值分群并生成零发送的仅审阅 `invite_segment`
草案。本地 R 4.6.1 检查及 `dfdfd558` 教程 CI 通过。它不发送消息、不发布
活动、不读取任意数据、不调用真实模型。
R 的 `Tutorial/wealth-analysis/` 对固定 `acct-100` 组合计算加权风险 `0.54` 与集中度
`0.60`，建议 `rebalance`，并生成 `trades_executed=0` 的仅审阅提案。本地 R 4.6.1
检查及 `dfdfd558` 教程 CI 通过。它不交易、不使用市场数据、不提供理财建议、
不调用真实模型。
COBOL 的 `Tutorial/batch-exception-review/` 复用现有确定性批处理交接，检查已审阅、
不可用和超时路径，同时保持批输出与异常文件不变。本地 GnuCOBOL 2.0.0/Python 检查通过，
Linux CI 也已在 `01d9b1ff`（run `45040372057`）通过。它不实现真实记账、持久队列、
恢复证明或真实模型。
Julia 的 `Tutorial/experiment-comparison/` 通过原生 Julia Core 计算固定
baseline/candidate 指标，并把计算证据封装进报告。本地 Julia 1.13.2 检查通过，
Linux CI 也已在 `bbf12c42`（run `45041423996`）通过。它不读取任意数据、不执行模型
提供的 Julia 代码、不安装包、不调用真实模型。
Fortran 的 `Tutorial/simulation-metrics/` 通过原生 Fortran Core 计算固定十样本指标
（均值、最小值、最大值、峰峰值、两个超阈值点），并把计算证据封装进 `draft_only`
报告。本地 gfortran 16.2.0/RE2 检查及 `dfdfd558` 教程 CI 通过。它不读取
任意数据、不执行模型提供的 Fortran、不安装包、不发布报告、不调用真实模型。
Octave/MATLAB 的 `Tutorial/signal-trends/` 通过共享 Core 计算固定信号的均值、峰峰值、
RMS 与阈值异常，并把证据封装进报告。本地 GNU Octave 11.3.0 检查通过，Linux CI 也已
在 `0664a194`（run `45042266323`）通过；原生 MATLAB 未验证。它不读取任意文件、不执行
模型提供的代码、不控制设备、不调用真实模型。
Python 的 `Tutorial/office-qa/` 增加带引用的办公政策问答路径，使用固定文档、受限搜索、
拒绝与索引失败检查。本地 Python 检查通过，Linux CI 也已在 `cfd850a6`（run
`45043537084`）通过。它不读取任意文件、不调用 Connector、不发送邮件、不使用真实模型。
Python 的 `Tutorial/insurance-claims/` 读取固定 `claim-100` 文件，计算确定性风险信号，
生成仅审阅的赔付草案，并通过 `StructuredOutput` 校验最终报告（格式错误会抛出
`StructuredOutputError`）。本地 Python 3.14 检查及 `dfdfd558` 教程 CI 通过。
它不执行支付、不做承保决定、不读取任意文件、不使用真实模型。
Python 的 `Tutorial/legal-compliance/` 在固定政策 fixture 中检索引用，并把
`publish_memo` 置于 Core 中断门后：批准则执行模拟发布，拒绝抛出
`ApprovalDeniedError` 且零发布，越界查询在读取前被策略拒绝。本地 Python 3.14 检查
及 `dfdfd558` 教程 CI 通过。它不提供法律意见、不记录真实审批、不写入文档库、
不使用真实模型。
Python 的 `Tutorial/education-tutoring/` 用应用自有 `LessonRetriever` 实现 Core
`Retriever` 协议并返回带类型的 `Document`，引用 `lesson-fractions` 并生成
`assignments_created=0` 的仅审阅学习计划。本地 Python 3.14 检查及 `dfdfd558` 教程 CI
通过。它不使用学生数据、不创建作业、不保证课程正确性、不调用真实模型。
TypeScript 的 `Tutorial/customer-support/` 通过 SSE 流式输出带引用的客服回复，使用固定
订单/政策工具，包含鉴权、拒绝与依赖失败检查。本地 Node 24 检查通过，Linux CI 也已在
`39558592`（run `45086046576`）通过。它不发送回复、不修改订单、不退款、不使用真实模型。
TypeScript 的 `Tutorial/travel-booking/` 检查固定 `trip-100` 库存并生成仅审阅占座草案
（`payment_executed=false`、`bookings_writes=0`）；`trip-200` 被策略拒绝，模拟库存错误在
一次读取后失败。本地 Node 24 检查及 `dfdfd558` 教程 CI 通过。它不支付、不出票、
不修改库存、不使用真实模型。
Java 的 `Tutorial/wealth-service/` 读取固定组合并生成仅审阅重平衡草案，包含策略拒绝和
loopback HTTP 边界。本地编译通过；本地 JVM 阻塞运行，Linux CI 也已在 `827d47ca`
（run `45088386879`）通过。它不交易、不转账、不使用市场数据或真实模型。
C# 的 `Tutorial/sales-crm/` 读取固定客户并生成仅审阅跟进草案，包含策略拒绝和 loopback
HTTP 边界。本地 .NET 8 构建与自测通过，Linux CI 也已在 `00641594`（run
`45093076768`）通过。它不写 CRM、不发送邮件、不使用真实客户或真实模型。
C# 的 `Tutorial/healthcare-scheduling/` 读取固定 `appointment-100` 诊所排班并生成仅审阅
预约草案（`booking_writes=0`）；`appointment-200` 被策略拒绝，模拟排班错误在一次读取后
失败。本地 .NET 8 构建/自测及 `dfdfd558` 教程 CI 通过。它不写排班、不确认预约、
不使用患者身份或真实模型。
Lua 的 `Tutorial/host-embedding/` 把原生 Lua Core 嵌入宿主事件循环，使用固定只读设备
状态与仅草案动作回调。本地 Lua 5.4.6 检查通过，Linux CI 也已在 `9163d03a`（run
`45095923385`）通过。它不发送设备命令、不打开 Socket、不使用真实模型。
Rust 的 `Tutorial/iot-gateway/` 通过显式的应用自有 `GatewayAdapter` trait 读取固定
`device-100` 遥测，并生成仅审阅运维动作草案。本地 Rust 检查通过，Linux CI 也已在
`a78de75e`（run `45098362060`）通过。Adapter 是进程内 fixture，不实现 MQTT、OPC UA、
Socket、设备命令或真实模型。
Zig 的 `Tutorial/gateway-health/` 通过显式的应用自有 `GatewayAdapter` 函数表检查固定
`gateway-100` 快照，并生成 `restart_telemetry` 仅审阅动作草案。本地 Zig 0.17.0 检查
通过，Linux CI 也已在 `0b2f15d6`（run `45102354617`）通过。它不实现 MQTT、OPC UA、
Socket、设备命令或真实模型。
Go 的 `Tutorial/incident-coordination/` 通过应用自有 `IncidentSource` 读取固定
`incident-100` 快照，生成 `notify_oncall` 更新草案，并通过 `event.FuncSink` 记录
`run.started`/`tool.call`/`run.completed`。本地 `go test` 与 `go run --test` 通过；
`dfdfd558` 教程 CI 通过。它不连接真实事件系统、不启动持久工作流、不修改事件、
也不调用真实模型。
Go 的 `Tutorial/soc-alert-triage/` 通过应用自有 `AlertSource` 读取固定 `alert-100`
快照，用 Core `PIIRedactor` 脱敏报告人邮箱与电话，生成仅审阅 `isolate_host` 草案，并通过
`event.FuncSink` 记录审计事件。本地 `go test` 与 `go run --test` 通过并断言原始 PII
不存在；`dfdfd558` 教程 CI 通过。它不连接真实 SIEM、不执行主机动作、不调用真实
模型，也不对运行期工具参数、错误或事件载荷脱敏。
Go 的 `Tutorial/logistics-checkpoint/` 评估固定 `shipment-100`，把对话记录序列化为
`checkpoint.Checkpoint`，并在第二轮恢复后生成仅审阅改道草案（不再重复读取，`reads`
保持 1、`drafts` 达到 1），并保存扩展后的 checkpoint。本地 `go test` 与 `go run --test`
及 `dfdfd558` 教程 CI 通过。存储仅是内存 JSON 往返，不是数据库、并发存储或
exactly-once 证明，也不连接真实物流系统或真实模型。
Go 的 `Tutorial/evidence-vault/` 从受限根目录的 `vfs/localfs` 后端读取唯一允许的
`evidence-100.txt`，拒绝 `../secret.txt` 与绝对路径，并生成 `case_writes=0` 的仅审阅
发现。本地 `go test` 与 `go run --test` 通过并断言 containment；`dfdfd558` 教程 CI
通过。证据库是临时目录，不是加密存储或生产沙箱，且不连接案件系统或真实模型。
C 的 `Tutorial/device-diagnostics/` 通过应用自有 `PxDeviceAdapter` 函数指针读取固定
`device-100` 快照，并生成 `notify_operator` 仅审阅动作草案。本地 MinGW gcc/CMake 检查
及 `dfdfd558` 教程 CI 通过。它不实现串行总线、Socket、设备 SDK、设备命令或
真实模型。
C++ 的 `Tutorial/industrial-edge/` 通过应用自有 `DeviceAdapter` 接口读取固定
`edge-100` 快照，并生成 `schedule_maintenance` 仅审阅动作草案；Adapter 失败时抛出
`DEVICE_READ_FAILED`。本地 MinGW g++/CMake 检查及 `dfdfd558` 教程 CI 通过。
它不实现现场总线、OPC UA、Socket、设备 SDK、设备命令或真实模型。场景地图、
当前状态、交付标准与后续候选见 [Tutorial 整体规划](../getting-started/tutorial-plan.md)。

### 开发者成果

将首次运行扩展为一个有用的本地应用，例如：

- 结构化输出处理器；
- MCP 工具助手；
- 只读 Workspace 助手；
- 带事件或 OpenTelemetry 输出的 Streaming Agent。

### 立即开始

- [示例目录](../getting-started/examples.md)
- [配方](../guides/recipes.md)
- [集成 Adapter](../integrations/index.md)
- [Plugin 指南](../guides/plugins.md)
- [多 Agent 模式](../guides/multi-agent.md)
- [代表性链路教程](../guides/representative-chain-tutorial.md)，包含 Go 真实模型
  链路和全部 wired 语言的确定性对应链路
- `examples/` 下的 `reference`、`governed-workspace`、`checkpoint`、`plugin` 和
  `recipes` 示例

### 下一步工作

- 保留已有 Basic、Integration、Hardening、Advanced 分组，区分机制检查、Core 集成、
  应用教程和有记录的运行；只有源码文件不代表路径可用。
- 先为明确消费者验证一个应用型原型，再扩展其他 SDK 教程。
- 按实际传输方式和命令审计已有 MCP 示例；只补消费者需要的缺失行为。
- 统一 Adapter 页面的安装、认证、最小示例和限制说明。

## 阶段 3：嵌入实际应用

### 开发者成果

将 Core 接入现有服务，同时由应用负责：

- 配置和 Provider 凭据；
- 已认证身份和策略决策；
- 明确的工具与资源范围；
- Checkpoint 或应用状态持久化；
- 事件、Telemetry、取消和优雅退出；
- Shell、文件或网络效果周围的隔离。

### 立即开始

- [采用指南](../getting-started/adoption.md)
- [应用嵌入清单](../guides/application-integration-checklist.md)
- [集成指南](../guides/integration.md)
- [身份与策略配方](../guides/identity-policy.md)
- [长时操作配方](../guides/long-running-operations.md)

### 下一步工作

- 按消费者需要向更多 SDK 扩展身份能力。
  [TypeScript OIDC 示例](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/service-auth)
  已支持 Token introspection、撤销和 provider discovery。
  [Go](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth)、
  [Python](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service-auth)
  与 [C#](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/service)
  示例均支持带 provider discovery 的 OIDC/JWKS，并保留应用局部 HMAC 路径；Python
  还支持应用拥有的 HTTP 策略决策服务。
- 保持[应用嵌入清单](../guides/application-integration-checklist.md)与只读、有副作用、
  高风险三档一致。
- 在真实消费者中使用 [Checkpoint Store
  配方](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/checkpoint-store-go)
  和 [续跑指南](../guides/checkpoint-continuation.md)，并记录结果；不要把配方等同于并发
  数据库、exactly-once 或持久 lease 服务。

## 阶段 4：加固与维护

完整测试和验证从这一阶段开始成为主要工作。它们用于增强已经存在的应用，不应阻塞
开发者获得第一个有用结果。

### 开发者成果

- 拒绝和依赖故障路径失败关闭；
- 编辑后的最终工具参数重新授权；
- 未知结果不被盲目重试；
- 本地取消不被误认为远端效果已取消；
- Checkpoint 不被当成事务；
- 框架升级后仍保持应用要求的行为。

### 后期工作

- 保持[应用嵌入清单](../guides/application-integration-checklist.md)与只读、有副作用、
  高风险三档一致。
- 扩展[消费者测试模板](../guides/consumer-test-template.md)，增加语言示例，不要求复制
  整个仓库矩阵。
- 测试 assistant 输出、应用保存的工具结果和外部写入的两轮记忆写入/召回；断言召回
  不进入 system，策略拒绝仍然零效果，不由此推断通用提示注入防护。
- 保留未知效果重试用例：传输或超时错误不能证明非幂等工具没有产生效果。
- 对真正需要的集成执行升级、故障、负载、Provider、数据库、Collector、Sandbox
  和恢复检查。
- 将 [Execution Correctness](execution-correctness.md)、Behavior Lab、兼容性和
  [验证证据](verification-evidence.md)作为维护与发布质量工作继续推进。

[兼容政策](compatibility-policy.md)和安全修复贯穿所有阶段；后移的只是完整验证。

## 阶段 5：高级与实验集成

高级工作按真实项目需求推进，不按框架完整度分数推进，包括 Plugin、本地委派、MCP/A2A、
Provider-neutral Workspace、远端长时操作和具身集成。

继续使用一个 Kernel 和文档中的[集成层次](../reference/execution-profiles.md)。Governed
与 Embodied Profile 是集成设计，不是独立 Kernel，也不是新用户的必选起点。

AKROVELA 是具身试点选定消费者，PRAXOVELA 是另一个独立产品消费者。具体状态和验收条件
保留在[具身试点计划](embodied-pilot.md)；具身工作不属于普通 SDK 采用主线。

受控委派属于提案，需明确消费者，并在公共 API 变更前完成语义评审。区分父代理可调用的
工具与可委派的权限：父代理可以只调用 `delegate`，同时授权子代理使用独立批准的
`read_file` 能力。需定义不可绕过的父策略组合、跨兄弟任务累计预算、子任务数和深度限制、
取消/截止时间传播及最终参数重授权。实现并版本化之前仍由应用强制执行。全部
十六种 wired 语言都有应用级负向测试，覆盖范围收窄、父子策略组合、兄弟共享预算、
子任务数/深度限制、取消后零效果和最终参数重授权；扩展实现使用原生测试套件或
示例目录。它们不提供 Core 强制继承；公开 API 与 profile 变更仍需门禁。

没有明确消费者和具体缺口时，不优先增加 ROS、Workspace Provider、新语言或通用异步
Action API。

## 当前优先项

1. **P0：交付生态原生参考应用。** 按下表顺序，从 PHP 原生业务应用开始，证明既有宿主与
   运行时集成，而不是再写一套通用 Agent Loop。先交付一条连贯路径，再扩展下一项；
   以下是拟建设应用，不是已完成示例，也不是同时启动全部项目的承诺。
2. **P0：与消费者验证参考路径。** 从发布包安装/运行/拒绝，推进到真实 Provider 工具调用与
   应用集成，记录耗时、失败、作者协助与独立复现。第三方持续使用、经同意可核验的非作者
   生产应用分别作为后续里程碑，不当作当前事实，也不阻塞基础示例发布。
3. **P1：稳定用户选择的路径。** 对所选主流 SDK 运行文档公开 API 与不改消费者源码的升级
   检查，发布迁移说明、修复实际破坏，不承诺所有 API 相同或冻结全部 `0.x` 包。
   仅在复现尝试或明确消费者证明需求后深化生态教程。
4. **P1：测量选型并维护真实分发。** 用有界 [Agent Selection Benchmark](adoption-baseline.md)
   检验工具能否正确选择并运行已具备的参考路径，分别记录候选出现、推荐排名、排除、
   安装/构建、行为与修复成本。它服务于参考应用，不先于应用，也不扩为大规模模型/Skill
   对比。Registry 版本、包说明、Coding Agent 包映射和双语
   证据一起维护。描述原生嵌入、Provider 选择与共享治理契约的组合及各 SDK 限制，
   不宣称普遍功能对齐或优于编排框架。
5. **P2：补齐已证实缺口。** 正确性和安全修复贯穿全程；按实际使用推进 parity、委派语义
   或 Adapter。新增语言仍需消费者与维护者，无默认扩张配额；新增 Core API 前先复用
   Checkpoint 配方。

这些优先项选择少量完整路径，而不是更多孤立功能。一个 Go 示例不能证明其他语言 SDK
的开发者路径同样可用，Registry 下载量也不等于采用。

主流 SDK 是基本盘；既有运行时和长尾集成是实验，不是已证实市场。候选宿主包括
Laravel/Drupal、Rails、Spring Boot、Phoenix/OTP、PowerShell 运维、Perl 存量系统、
C/C++ 嵌入、Fortran/R 分析、Rust 网关与 Go 服务。这些是选型假设，不是已交付集成或
市场份额排名。需比较原生嵌入、简单工作流和外部编排的维护/部署成本与持续使用意愿；
竞争者少不证明需求大。保留有用基础切片，不要求每条都深化成宿主集成。

外部定性评分与建议投入比例不是已测量事实或资源承诺。按用户阻力、复现结果、维护能力和
预期学习价值安排工作。共享契约是待验证的技术差异，不是已经成立的竞争壁垒。

### 参考应用顺序

下一阶段以参考应用为重点，按以下顺序推进。参考应用统一放在
`language/<language>/application/`；教程与机制示例仍保留在
`language/<language>/Tutorial/` 及既有路径。参考应用必须是 AI-native：Agent 驱动主流程，
而不是传统应用外挂一个审阅端点。验收问题、场景地图与 PHP/Java 流程提案见
[AI-Native 参考应用设计](ai-native-reference-applications.md)。PHP 在子目录保留前驱与
AI-native 两个版本；其他语言直接实现 AI-native 流程，不再先做传统应用前驱。
既有切片可以复用，但不算参考应用已完成。
遵守语言选择门槛，先明确公开范围、运行时、依赖版本和限制，再声明生态集成。
具体执行顺序与操作流程留在内部文档。

| 优先级 | 语言 | 拟建设参考应用 | 必须演示的生态行为 |
| --- | --- | --- | --- |
| 1 | PHP | Drupal CMS 编辑流程与 Laravel 内容门户 | 内容管理与编辑门户是 PHP 的典型场景，不是订单处理。演示 CMS/门户启动、路由或命令、容器/服务接线、已认证编辑上下文、文章工作流与仅审阅发布。首个实现是 Laravel 内容门户，下一宿主为 Drupal 模块。联测框架授权和 Core 工具策略，不强制 Python sidecar 或独立 Agent 服务 |
| 2 | Java | Spring Boot 电商目录、订单与结算 Agent | 电商是 Java 企业应用的典型场景：Spring Boot 服务、商品域、库存/订单工具、事务边界、身份传递、审批与审计。区分应用事务和远程效果；银行/ERP 为次要场景 |
| 3 | Elixir / Erlang | OTP 实时消息、电信与高可用运维 Agent | 实时消息、通知、电信与 OTP 监督是 Erlang/Elixir 的典型场景。验证监督树、故障/重启、有界工作、取消与未知效果重试前对账；AIOps 为次要场景。Elixir 与 Erlang 入口分别记录 |
| 4 | Go | 云基础设施与 DevOps Agent | 服务、CLI、控制平面和基础设施自动化是 Go 的典型场景。使用既有服务/CLI、基础设施客户端接口、取消/deadline、追踪和操作 allowlist；先只读，变更操作设门禁 |
| 5 | C++ / Rust | C++ 工业/嵌入式设备 Agent；Rust 系统/边缘服务 Agent | C++ 典型用于工业、嵌入式和性能敏感宿主；Rust 典型用于系统、CLI 和边缘服务。使用一个真实设备 SDK、仿真器或 transport、资源与生命周期边界、命令授权、取消确认和效果观察验证。C++ 与 Rust 分开记录 |
| 6 | COBOL | 银行/保险批处理异常分析 | 十进制/定长记录批处理是 COBOL 的典型场景。验证主批输出不变、确定性异常审阅、失败隔离、积压/恢复，并比较不嵌入 Core 的外部 worker |
| 7 | Julia | 科学计算与数值优化 Agent | 数值/科学计算是 Julia 的典型场景。使用实际数值/优化依赖或既有科研应用、可执行可行性/目标值检查与附证据解释；仅枚举不算求解器集成 |
| 8 | Ruby | Rails 电商/SaaS 后台 Agent | Rails Web 应用与电商/SaaS 后台是 Ruby 的典型场景。使用 Rails 启动、已认证租户上下文、Active Record 或 Active Job 边界、草案/审批/重放测试；数据库事务不等于外部 exactly-once |

下表的语言不属于首批八项，按常见运行时角色选择典型场景。它们是选型假设，
不是市场份额排名、交付承诺或生态优势证明。既有切片仍是有限集成检查，达到参考应用
验收标准后才能升级。

| 语言 | 典型场景 | 当前状态 |
| --- | --- | --- |
| Python | 数据/AI 流水线、自动化、Django/FastAPI 服务 | 拟建设 |
| TypeScript | Web 前端/BFF、Node 服务、店面 | 拟建设 |
| C# | 企业业务系统、ASP.NET Core 服务、Windows 集成 | 拟建设 |
| Perl | 日志/文本处理与既有自动化 | 既有 log-triage 切片 |
| Lua | 宿主嵌入与扩展/游戏脚本 | 既有 host-embedding 切片 |
| C | 嵌入式/受约束宿主组件 | 既有 device-diagnostics 切片 |
| Fortran | 数值仿真 | 既有 simulation-metrics 切片 |
| R | 统计分析与报告 | 既有 data-quality 切片 |
| PowerShell | Windows/IT 运维自动化 | 既有 windows-diagnostics 切片 |
| MATLAB/Octave | 信号处理与数值分析 | 既有 signal-trends 切片；原生 MATLAB 未验证 |
| Swift | Apple 平台应用 | 拟建设；服务端 Swift 不是主要场景 |
| Kotlin | Android/JVM 服务 | Java Core 上的示例 |
| Scala | JVM 数据工程 | Java Core 上的示例 |
| Dart | Flutter 应用 | 拟建设 |
| Haskell | 编译器与领域建模 | 既有 rule-DSL 切片 |
| OCaml | 编译器与静态分析 | 既有 static-diagnostics 切片 |
| Zig | 系统/嵌入式组件 | 既有 gateway-health 切片 |
| D | 系统/数据处理 | 既有 data-pipeline 切片 |
| Nim | 系统/CLI | 既有 maintenance-triage 切片 |
| V | CLI/系统 | 既有 release-preflight 切片 |
| Delphi | 桌面业务应用 | 既有迁移/RPA 切片 |
| Objective-C | Apple 旧有应用 | 既有隐私切片 |
| Shell/Bridge | 进程编排与宿主自动化 | 仅 Bridge 契约 |

**当前进度（2026-11-25）。** 优先级 1 在
[`language/php/application`](https://github.com/axisvela/praxo-core/tree/main/language/php/application)
下有两个 Laravel 12 路径：`content-review/` 是宿主集成前驱，`ai-editorial-studio/`
是 AI-native 参考实现。AI-native 版本接收选题、检索既有内容、由模型生成草案/分类/SEO，
保存草案并创建仅审阅发布请求；直接发布选题在检索、起草或发布前被拒绝。
它安装已发布 `axisvela/praxo-core==0.8.1`，本地确定性测试 9/9 通过（56 条断言）；
前驱 7/7 通过（29 条断言）。订单/结算留给 Java 电商参考应用；Drupal 仍是下一 PHP 宿主。
2026-11-25 使用托管 DeepSeek `deepseek-flash` 完成一次真实运行：`model=live`，trace 为
`search_content` -> `draft_article` -> `suggest_taxonomy` -> `request_publish_review`，
生成模型理由（最近一次 858 字符），`publications_executed=0`。运行使用自定义 cURL transport 处理
本地代理/CA；没有独立复现或生产部署。应用 CI 矩阵已添加但尚未运行。

优先级 2 已有 Spring Boot AI 电商源码：
[`language/java/application`](https://github.com/axisvela/praxo-core/tree/main/language/java/application)。
它使用已发布 `com.axisvela:praxo-core:0.11.0`，实现意图 -> 商品/库存 -> 购物车草案 ->
仅审阅结算，checkout 始终拒绝。源码现已记录模型理由与 `agent_trace`，但本地 Windows JVM
仍阻塞，因此尚未本地编译或测试，也没有真实模型运行记录；Linux CI 作业已添加但尚未运行。
在该作业通过前，不把 Java 视为已验证。

优先级 3 已有 Elixir OTP AI 运维 Copilot：
[`language/elixir/application`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/application)。
它运行监督树中的遥测存储与修复执行器，检索遥测、生成仅审阅修复，并拒绝直接执行。
本地源码模式在 Elixir 1.20.4 / OTP 29 上 6/6 通过，包含租户拒绝与监督进程重启；本地 Hex 安装
遇到 unknown-CA 失败，CI 作业使用已发布 Hex 包且已添加但尚未运行。2026-11-25 使用托管
DeepSeek `deepseek-flash` 完成一次真实运行：`model=live`，模型先选择
`search_signals(service-100)`，再生成包含 diagnosis/rationale 的 `draft_remediation`，
最终 `executions=0`。更早一次尝试把展示名 `checkout` 当作 service id，被策略拒绝；
把授权 service id 加入提示词后模型自行改对。

优先级 3 也已有 Erlang OTP AI 运维 Copilot：
[`language/erlang/application`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/application)。
它把 Erlang Core 源码与 OTP 监督树一起编译，源码模式 6/6 通过（含监督进程重启），并拒绝
直接修复。2026-11-25 使用托管 DeepSeek `deepseek-flash` 完成真实运行：`model=live`，模型
选择 `search_signals(service-100)`，再生成包含 diagnosis/rationale 的 `draft_remediation`，
最终 `executions=0`。live transport 使用 `httpc` 与本地代理/CA。

优先级 4 已有 Go AI 基础设施 Agent：
[`language/go/application`](https://github.com/axisvela/praxo-core/tree/main/language/go/application)。
它提供 HTTP 端点与 CLI，通过 module replace 使用本地 Go 参考源码，8/8 测试通过，拒绝直接
修复，并记录 `agent_trace`。使用托管 DeepSeek `deepseek-flash` 的真实运行记录 `model=live`，
三步 trace（`search_signals` -> `draft_remediation` -> 最终报告），模型生成的
diagnosis/rationale，`executions=0`。Go CI 已添加但尚未运行。

优先级 5 已有 Rust AI 边缘网关 Agent：
[`language/rust/application`](https://github.com/axisvela/praxo-core/tree/main/language/rust/application)。
本地测试 6/6 通过，使用应用自有 `GatewayAdapter`，记录模型选择的工具与 `agent_trace`。
live 路径已接线，但本地 TLS backend 因 `ring` 缺少原生 C 头文件而无法构建，因此没有 Rust
真实运行记录。C++ 对应实现位于
[`language/cpp/application`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/application)：
本地 CLI 五项检查通过，使用应用自有 `GatewayAdapter`，并记录 `agent_trace`。C++ live 未实现，
因为 Core adapter 需要应用提供 HTTP transport。优先级 6 已在
[`language/cobol/application`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/application)
实现：原生 `praxo-run` 批处理异常分析通过五项确定性检查及批处理文件检查；私密记录、直接
过账和租户不匹配均被拒绝，且不提交可执行文件。COBOL 未捆绑 HTTP/TLS transport，因此没有
真实运行记录。优先级 7 已在
[`language/julia/application`](https://github.com/axisvela/praxo-core/tree/main/language/julia/application)
实现：原生 `LinearAlgebra` 响应面 Copilot 通过六项确定性检查，托管 DeepSeek
`deepseek-flash` 真实运行记录 `model=live`、模型选择工具、计算拟合证据和 `writes=0`。
优先级 8 仍为拟建设。其他语言直接实现 AI-native 应用。

确定性 harness 测试不是真实模型推理证据。PHP、Elixir、Erlang、Go、Julia 已有真实模型运行
记录；Java、Rust、C++、COBOL 还没有。AI-native 验证声明需要模型 ID、模型选择的工具、生成内容、策略边界、
trace、延迟与成本。交付跟踪见 [#34](https://github.com/axisvela/praxo-core/issues/34)。

每项参考应用应包含所选已发布 Core 包的可复现安装、真实宿主入口、有用的端到端任务、
无需凭据的确定性模式、独立可运行的真实模型路径、显式工具策略、副作用前拒绝与依赖失败
测试、预期输出、CI，以及应用自有的身份/状态/效果边界。源码、宿主运行、真实 Provider、
独立复现和持续使用分别记录。包、运行时、宿主或凭据不可用时标为阻塞，不算通过；
不预设新增 Core API。

尤其对 PHP、Elixir、Erlang、COBOL，下一步不再证明语言“能够实现 Agent”，而要验证
Core 如何利用现有软件生态与运行时，以比简单工作流或外部编排更低的接入/运维阻力解决
真实任务。这是需要测量的权衡，不能由支持语言数量或竞争者少直接推断。

外部验证需求分别记录在 [#30](https://github.com/axisvela/praxo-core/issues/30)
（独立计时）、[#31](https://github.com/axisvela/praxo-core/issues/31)（托管端点）、
[#32](https://github.com/axisvela/praxo-core/issues/32)（外部消费者路径）和
[#33](https://github.com/axisvela/praxo-core/issues/33)（Registry 安装）。关闭内部
文档缺口不等于关闭外部证据缺口。

## 采用证据

采用工作分别回答三个问题：开发者能否发现框架、能否完成指定集成、能否在变更后继续
维护。详细方法保留在[采用基线协议](adoption-baseline.md)。

这些实验应在实用路径存在后用于改进文档，不阻塞 Quickstart、示例或集成发布。
有用信号包括首次结果耗时、完成率、修复成本、Issue 质量、完成升级和真实项目中的持续使用。
Registry 下载量本身不等于采用。

## 采用路径稳定后再做

- 仅为增加数量而扩展 Behavior Lab 或兼容矩阵。
- 在没有明确消费者、维护者、真实部署路径和集成证据时，新增语言 Kernel、仓库或大量
  Adapter。
- 在消费者需要崩溃步骤恢复、待处理审批、效果游标或 exactly-once 语义并提供真实恢复
  测试之前，实现 durable execution 模块。
- 每次文档变更后重跑全部历史证据记录。
- 大规模编程 Agent Skill 对比和重复采用实验。
- 为没有活跃消费者的集成补齐全部故障、负载、真实 Provider 和运行证据。
- 在没有维护者和用例时增加语言实现或 Adapter。
- 将具身仿真、硬件或机器人中间件作为通用 SDK 目标。

这些仍是有价值的后期工作，但不是首次开发体验。

## 生态边界

PRAXO-CORE 是可复用 MIT 框架，不是产品平台。PRAXOVELA、AKROVELA、其他 AxisVela
产品和独立应用使用相同公开契约，同时拥有各自的状态、身份、策略服务、工作流、网络、
部署与用户体验。

Core 提供 Model、Tool、Policy、Event、Checkpoint、Plugin、Stream 和 Workspace 接口。
它不运营身份提供商、策略决策服务、工作流引擎、效果账本、网络控制平面或托管 Sandbox。
可选 AxisVela 映射见[生态集成](../integrations/ecosystem.md)。

## 兼容承诺

- 保持 Go 公共 API 精简并维持 MIT 边界。
- 共享 Wire 变更必须显式进入 `spec/`。
- 不仅为简化语言移植或示例而扩大 Go API。
- 允许各语言保持符合本语言习惯的 API；移植不要求镜像 Go 内部实现。
- 在消费者证明可复用 Core 缺口前，优先使用示例和 Adapter。
- 保留已发布 URL，并为破坏性变更提供迁移指南。

参见[兼容政策](compatibility-policy.md)、[Core 支持](../languages/support.md)和
[语言规范](../contributing/language-policy.md)。

## 状态与已交付内容

路线图说明方向，详细状态与验证保留在：

- [契约与证据状态](contract-status.md)
- [版本历史](../releases/index.md)
- [验证证据](verification-evidence.md)
- [完整变更日志](https://github.com/axisvela/praxo-core/blob/main/CHANGELOG.md)
