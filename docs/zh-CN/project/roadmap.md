# 公开路线图

当前核心版本为 `2.8.0`。

本路线图按开发者成果组织：判断是否适用、跑出有用结果、完成真实原型、嵌入应用，
最后再加固具体集成。它不是交付排期、产品路线图，也不表示所有语言实现都支持每项能力。

## 下一阶段方向

**规划更新：2026-11-13。** 当前首要目标是缩短从发现框架到做出有用项目的路径。
新用户不需要先理解完整规范、证据分类、跨语言矩阵或高级执行 Profile，才能开始开发。

**规划更新：2026-11-16。** 下一阶段重点是证据深度和第一条可用路径，而不是增加语言
条目。第一条路径是五分钟嵌入，治理验收是第二步。公开声明区分契约完成、Adapter 可用
和集成已验证。Go 源码提交 `73da5139` 已将记忆召回移出 system 角色，但尚未发布；
`2.8.0` 仍使用旧角色。该修复不防止所有提示注入，也不代表全部 SDK 具有相同行为。
工具参数在编辑后仍重新授权。

PRAXO-CORE 继续定位为**可治理、可嵌入的 Agent 执行框架**。路线图优先完整可运行的
应用路径和清晰集成边界，不追求语言、Adapter、Profile 或测试数量。既有系统和受约束
运行环境是主要集成目标；新增语言 Kernel 或 Adapter 仍需要明确消费者、维护者和真实
部署路径。

### 规划原则

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

## 采用路径

| 阶段 | 开发者成果 | 当前状态 | 下一项成果 |
| --- | --- | --- | --- |
| 0. 判断 | 知道 Core 是否适合，以及该选择哪种语言和路径 | 已有概览、任务入口、对比和非目标说明 | 缩短选型路径，明确应用仍需负责什么 |
| 1. 运行 | 安装发布包、连接模型、注册一个工具并得到有用结果 | 已有发布包确定性 Starter 和真实模型示例；五分钟完成尚未经过独立计时。注册表状态单独记录在语言支持页面。live-model 指南已覆盖端点、模型 ID、凭据、超时、Tool Schema 和平台排错 | 使用排错指南分别测量确定性嵌入和真实端点完成情况 |
| 2. 原型 | 完成一个包含工具、Streaming、结构化输出、MCP、Workspace 或 Telemetry 的连贯本地应用 | 十三个主题在三十一种语言中有源码入口，但深度从孤立机制检查到 Core 集成、应用教程不等；目录已按任务分组 | 审计示例深度与运行命令，再验证一个消费者选定的应用路径 |
| 3. 嵌入 | 将 Core 接入现有服务，由应用管理身份、策略、持久化、事件和退出 | 已有厂商中立的 Go/Python/TypeScript 服务和认证身份/策略服务；Go、Python 和 TypeScript 均支持带 provider discovery 的 OIDC/JWKS、RFC 7662 introspection 和 RFC 7009 撤销；另有 Python 可选外部策略决策服务、已验证身份与持久 Checkpoint 变体和分档清单 | 将 Token introspection/撤销和外部身份模式扩展到更多 SDK；增加最小持久 Checkpoint 路径 |
| 4. 加固 | 让具体集成可升级、可失败、可取消、可恢复 | 已有负向、升级、隔离和恢复资产；未发布的 Go 记忆角色修复和重试风险测试有本地确定性覆盖。源码审计未发现其他 SDK Agent 主路径的自动召回，Bridge 仍未知。消费者测试模板已加入两轮记忆信任和未知效果重试/对账检查 | 验证并发布 Go 修复，核查 Bridge 是否暴露召回，并把模板应用到真实消费者 |
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

- 在首页和入门文档中统一一张“任务到路径”表。
- 分开“体验框架”“验证包”和“加固部署”三类路径。
- 用开发者能做成什么描述语言支持，不只展示契约层级和测试覆盖。

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
  [Go](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth)
  与 [Python](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service-auth)
  示例均支持带 provider discovery 的 OIDC/JWKS，并保留应用局部 HMAC 路径；Python
  还支持应用拥有的 HTTP 策略决策服务。
- 保持[应用嵌入清单](../guides/application-integration-checklist.md)与只读、有副作用、
  高风险三档一致。
- 在教学型 Checkpoint 示例和高级长时操作 Fixture 之间提供最小持久化路径。

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
取消/截止时间传播及最终参数重授权。实现并版本化之前仍由应用强制执行，现有父子示例
不能证明权限继承约束。

没有明确消费者和具体缺口时，不优先增加 ROS、Workspace Provider、新语言或通用异步
Action API。

## 当前优先项

1. 验证并准备发布 Go 记忆角色修复，补迁移说明、两轮回归和 SDK 影响审计；不把未发布
   源码行为写成发布包保证。
2. 验证一个消费者选定的嵌入路径：先确定性安装/运行/拒绝，再完成真实模型工具调用，
   测量时间、修复和作者协助。
3. 获取一个独立框架消费者和一次第三方复现。真实 Provider、MCP、Harmovela 分别记录；
   只有一次运行覆盖整条链路才能声称组合链路已验证。
4. 只深化该消费者证明的缺口；如需要受控委派，先做语义评审。新增 Store 或公共 API 前
   优先复用已有 Checkpoint Store 配方。
5. 保持证据等级和示例深度明确，从已验证路径产出任务教程，而不是再开全面 SDK 扩张。

这些优先项选择少量完整路径，而不是更多孤立功能。一个 Go 示例不能证明其他语言 SDK
的开发者路径同样可用，Registry 下载量也不等于采用。

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
