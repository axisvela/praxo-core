# 嵌入方式与执行 Profile

**设计状态：2026-11-08。** 一个 Agent Execution Kernel，一条 Core 版本线，三个集成层次。
它们不是三个 Kernel、发行包、构造器开关或新增公共 API；本设计不改变默认行为、Wire schema
或语言支持承诺。

各 SDK 和适配器仍独立版本化，不新增 Profile 专属发行线。

| 层次 | 当前状态 | 选型 |
| --- | --- | --- |
| Standard Embedding | 现有嵌入行为 | 嵌入循环，由应用显式配置所需控制 |
| Governed Execution Profile | 验收设计提案；已有部分集成证据 | 要求显式授权、操作绑定和故障处理 |
| Embodied Integration Profile | 设计提案；消费者试点未开始 | 为明确具身消费者增加远程动作与观测要求 |

Go 参考实现是行为起点，其他语言需分别声明控制能力与证据；同名层次不代表语言能力对齐。
参见[契约与证据状态](../project/contract-status.md)。

## Standard Embedding

Standard Embedding 命名现有普通嵌入方式，不是新的认证 Profile。应用使用现有 Agent、Model、
Tool 接口，配置预算和可选控制，负责部署与外部效果。

| Core 实现什么 | 测试验证什么 | 消费者必须提供什么 |
| --- | --- | --- |
| 局部模型/工具循环、已配置的 Policy/HITL、事件与取消 | 声明范围的单元/向量行为及发布包消费者 fixture | 模型适配器、工具、凭据和任务所需控制 |
| Session/Checkpoint 与 Sandbox 契约 | 指定测试的序列化、恢复/适配器行为 | 持久存储、效果对账与真实执行隔离 |

Go Agent 可以不配置 Policy，这不表示默认启用 fail-closed 安全模式。当前空 `AllowedTools`
表示不限制，而非全部禁止。Standard Embedding 可以使用严格控制，但控制存在不等于满足完整
Governed Execution Profile；框架可选不代表某个风险场景可以省略。

从[消费者 Starter](../getting-started/index.md)和[采用指南](../getting-started/adoption.md)
开始，固定实际包版本；接入真实 Provider 后仍保留确定性允许/拒绝测试。

## Governed Execution Profile

这是叠加在 Standard Embedding 上的集成验收契约，不是另一套循环。详细要求见
[Governed Execution Profile](governed-execution.md)：必需 Policy 与显式范围、可信调用者与资源绑定、
最终操作及审批绑定、必需依赖故障处理、上下文信任、效果恢复。

Core 执行已配置的 Hook 与生命周期检查；消费者拒绝缺失必需配置，并提供身份验证、按需持久审批/
证据、执行隔离和权威业务状态查询。Policy Hook 不能限制同进程恶意代码。必需证据故障必须有明确
策略；业务提交后的证据失败不得导致盲目重做效果。

发布包治理测试、身份和长时操作配方只证明各自断言，不证明通用 Profile 已实现、生产身份真实、
审批持久或完整部署安全。没有 `Profile: Governed` 开关或认证。

改进提案是消费者拥有的统一装配入口、结构化配置和依赖校验，而不是布尔安全承诺。
入口选择 G1-G8 义务，在暴露或执行前拒绝不完整装配，不回退 Standard Embedding。
Core、Effect PEP、远程权威和部署仍各自执行约束；配置校验与集成行为验收分别记录。
见[统一装配设计](governed-execution.md)，它不是已实现的复用包或 Core 新构造器。

## Embodied Integration Profile

这一领域集成提案增加治理验收要求，不替换或弱化它们。
[Embodied Integration Profile](embodied-integration.md)定义远程提交、反馈、观测新鲜度、
取消确认与效果验证。只有明确消费者、一个中间件和一个仿真场景就位后，才可称为实验性实现。

[试点计划](../project/embodied-pilot.md)拟通过既有接缝交付消费者示例、单个中间件实验适配器和
消费者局部操作/观测协议，复用治理装配并要求 G1-G8 加 E1-E8。新集成协议不自动成为
Core API 或共享 Wire；晋级依赖消费者证据与兼容审查。

工具今天就能调用机器人服务，但不表示满足该提案。调用成功或仿真通过均不证明硬件安全、实时控制、
认证隔离或急停行为。

## 选型与组合

| 需求 | 起点 |
| --- | --- |
| 本地助手或确定性工具循环原型 | Standard Embedding，显式选择控制 |
| 受保护企业工具或租户敏感操作 | 治理验收设计，加消费者提供的执行与证据 |
| 机器人或具身服务集成 | 治理要求，加具身设计和有边界的消费者试点 |
| 持久分布式工作流或安全控制器 | 外部工作流/执行/安全权威；三个层次均不提供这些服务 |

这些层次不是互斥运行模式或安全评分。更强名称不会自动产生外部控制。明确缺失要求与不支持能力，
不得静默退回 Standard Embedding；同时保留普通嵌入路径。

## 声明与兼容性

[Execution Correctness Suite 提案](../project/execution-correctness.md)按 EC-D、EC-I、EC-O
轨道定义失败边界验收。它是清单，不证明任一 Profile 已实现或已通过。

限定集成评估需记录层次/设计 revision、包版本与工件哈希、消费者场景、各要求的执行组件、配置、
实际测试结果和剩余缺口；区分已实现控制、fixture、提案与未验证部署属性。记录不是新 Wire 格式或证书。

`agent.Profile` 仍是默认参数集合，`model.ProviderProfile` 描述模型能力，workspace runtime profile
描述适配器能力；它们均不是执行 Profile 证明，也不会自动强制执行本设计。

优先复用接口。未来晋级共享 API/Wire 仍需明确消费者、负向测试、兼容评审、适用的规范性 `spec/`
更新、parity/conformance 与消费者验证。Profile 名称不能绕过要求，也不产生独立发行线。
