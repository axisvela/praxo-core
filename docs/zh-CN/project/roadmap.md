# 公开路线图

[100 个智能体场景目录](../getting-started/agent-scenarios.md) 将十六大领域映射到有界切片与
全部 31 个现有 Core 条目的候选分配。这是规划覆盖，不是 100 个应用已实现或跨语言 parity
保证。Ruby SE-07 FinOps 切片本地源码测试及 `dfdfd558` 教程 CI 通过，无云写入或真实
模型验证。

当前核心版本为 `2.11.3`。

本路线图按开发者成果组织：判断是否适用、跑出有用结果、完成真实原型、嵌入应用，
最后再加固具体集成。它不是交付排期、产品路线图，也不表示所有语言实现都支持每项能力。

## 相关页面

- [交付历史与应用状态](delivery-history.md)：记录已交付阶段、应用状态和采用证据。
- [契约状态](contract-status.md)：记录当前契约与证据快照。
- [验证证据](verification-evidence.md)：记录准确运行与限制。

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
| 独立 Core 实现 | 矩阵中的 Core SDK | 共享采用阶段，并在可行时提供可运行的 Provider、Tool 和集成路径；运行时和生态限制按语言记录 |
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
| 1. 运行 | 安装发布包、连接模型、注册一个工具并得到有用结果 | 已有发布包确定性 Starter 和真实模型示例；五分钟完成尚未经过独立计时。注册表状态单独记录在语言支持页面。live-model 指南已覆盖端点、模型 ID、凭据、超时、Tool Schema 和平台排错。Go、Python、TypeScript、C# 与 Rust 已记录本地 Ollama 工具调用（C# 与 Rust 通过构建后的二进制），但此 starter 路径尚无托管验证记录；另有七个参考应用的托管真实模型运行，不是 starter 路径验收。本地 Java JVM 仍受阻 | 分别记录独立确定性嵌入和真实端点完成情况；starter 托管端点见 [#31](https://github.com/axisvela/praxo-core/issues/31)，独立计时见 [#30](https://github.com/axisvela/praxo-core/issues/30) |
| 2. 原型 | 完成一个包含工具、Streaming、结构化输出、MCP、Workspace 或 Telemetry 的连贯本地应用 | 十三个主题在三十一种语言中有源码入口，目录已按任务分组；第一轮源码深度审计已区分 Core 引用、机制检查和传输中立 Handler，但不证明实际执行。端到端原型教程现包括 Go Workspace Agent 和 Python 结构化输出应用；其他示例多为集成检查 | 将源码深度审计转为消费者选定路径的运行记录；外部验证见 [#32](https://github.com/axisvela/praxo-core/issues/32) |
| 3. 嵌入 | 将 Core 接入现有服务，由应用管理身份、策略、持久化、事件和退出 | 已有厂商中立的 Go/Python/TypeScript/C# 服务和认证身份/策略服务；Go、Python、TypeScript、C#、Ruby、PHP 与 Rust 支持带 provider discovery 的 OIDC/JWKS；Java 示例已在 Linux CI 通过，本地 Windows JVM 仍受阻；31 个已声明实现中有 30 个提供源码级 RFC 7662 introspection 与 RFC 7009 撤销，其中 29 个本地运行验证（28 个原生运行时 + Octave 覆盖 MATLAB/Octave 共享模块），原生 MATLAB 未验证，COBOL 仅记录边界；另有 Python 可选外部策略决策服务、已验证身份与持久 Checkpoint 变体、分档清单，以及连接消息历史、allowlist Store 和操作状态的 Checkpoint 续跑指南 | 将 OIDC/外部身份模式扩展到更多 SDK，为消费者选定的语言补齐 registry 发布，单独记录原生 MATLAB，并为真实消费者验证 Checkpoint Store |
| 4. 加固 | 让具体集成可升级、可失败、可取消、可恢复 | 已有负向、升级、隔离和恢复资产；Go 记忆角色修复已在 `2.9.0` 发布，重试风险测试有本地确定性覆盖。源码审计未发现其他 SDK Agent 主路径或 Bridge `run`/`event stream` 路径的自动召回。消费者测试模板已加入两轮记忆信任、未知效果重试/对账检查和各语言起点；已对 10 个仓库自维护 fixture 中的 9 个完成运行，本地 Java 超时，这些都不是外部消费者 | 把模板应用到外部消费者；仓库 fixture 不能替代。见 [#32](https://github.com/axisvela/praxo-core/issues/32) |
| 5. 扩展 | 在需要时采用 Plugin、委派、长时操作、Workspace Provider 或具身集成 | 应用级委派示例覆盖 Go、Python、TypeScript、Java、C# 和 Rust；Go 参考示例覆盖长时操作、Workspace 和 Plugin | 在宣称受治理委派前，先实现父子策略、工具范围、预算和深度收窄 |

这些阶段表示推荐采用顺序，不是发布门禁，也不要求所有语言同步推进。

## 当前优先项

1. **P0：交付生态原生参考应用。** 按下表顺序，从 PHP 原生业务应用开始，证明既有宿主与
   运行时集成，而不是再写一套通用 Agent Loop。先交付一条连贯路径，再扩展下一项；
   以下是已有源码实现的验收目标，不是已完成宿主集成，也不是同时交付全部项目的承诺。
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

## 参考应用顺序

已移至[交付历史与应用状态](delivery-history.md#reference-application-portfolio)。

## 采用证据

已移至[交付历史与应用状态](delivery-history.md#adoption-evidence)。


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

已移至[交付历史与应用状态](delivery-history.md#status-and-delivered-work)。

## 采用阶段

阶段详情已移至[交付历史与应用状态](delivery-history.md#adoption-stages)。
