# 何时不应选择 PRAXO-CORE

本页用于帮助团队尽早排除 PRAXO-CORE。它不是对其他框架的贬低，也不能替代[框架对比](../project/evaluation/comparison.md)或[验证证据](../project/evaluation/verification-evidence.md)。

PRAXO-CORE 是一个可嵌入、MIT 许可的执行内核，提供显式的 policy、tool、checkpoint、event、memory 和 sandbox 接缝。它仍然刻意不是一个完整的 Agent 平台。

## 当前范围

框架已经超出最初的 Go 单内核范围：

- 超过三十个 Core 条目以及 bridge、sample 共享同一契约；
- 多个 Core 提供原生 OpenAI 兼容、Anthropic 和 Gemini 适配器，并可选接入 MCP、A2A、OpenTelemetry 和 Harmovela；
- Go 参考实现包含 checkpoint、HITL、子 Agent 委派、工作区会话以及 process/WASM 插件宿主；
- governed 和 embodied Profile 已有验收设计和范围化证据，但不是经过认证的生产 Profile。

这些能力减少了集成工作，但不会让 Core 变成托管运行时、连接器目录或服务提供方。下面的排除项说明的是平台责任边界，而不是缺少接口。

## 如果你的主要需求是以下能力，它可能不适合

- 托管式 Agent 服务或托管运行时；
- 可视化搭建器或低代码 Agent UI；
- 带持久子图、handoff 或共享图状态的图/工作流引擎；
- 模型提供商、路由服务或推理托管；
- 向量数据库、文档平台或完整记忆产品；
- 带热池、镜像目录、网络、配额和计费的 sandbox 控制平面；
- 托管身份提供商、策略决策服务、审批服务或效果账本；
- 业务效果 exactly-once 或跨服务事务保证；
- 以大量 provider、文档加载器和 RAG 连接器目录为核心的框架。

框架为其中若干问题提供了接缝和可选适配器，但不拥有其背后的服务或权威。

## 优先考虑其他方向

| 如果主要需求是 | 优先从何处开始 | 原因 |
| --- | --- | --- |
| 带持久状态的图/子图编排 | Eino、LangGraph 风格运行时或 RHEOVELA | Core 保持单 Agent 执行内核并支持异步子 Agent；图、handoff、共享状态和持久图恢复交给外部运行时 |
| 大量内置 provider、loader 和向量存储目录 | LangChainGo 或其他集成型框架 | Core 提供原生 OpenAI 兼容、Anthropic 和 Gemini 适配器以及可选 MCP/A2A/OTel/Harmovela 接缝，但不是广泛的连接器与 RAG 目录 |
| 带 sessions、tracing 和托管部署的运行时 | Google ADK、Microsoft Agent Framework 或 OpenAI Agents SDK | 这些产品覆盖更多应用运行时能力 |
| 以隔离代码执行为核心需求 | 专门的 sandbox 或 workspace provider | `sandbox.Sandbox` 是接缝，不是隔离产品 |
| 长期记忆、冲突处理和遗忘/审计策略 | 专门的记忆系统 | `pkg/memory` 是接口，不是完整记忆产品 |
| 非 Go 技术栈且不愿维护 provider 或工具适配器 | 受支持的语言 Core 或 bridge | 已有多种 Core，但声明范围、parity 和适配器覆盖不同；先核对矩阵 |
| 独立安全认证或经过审计的生产部署 | 具备第三方审查和部署证据的系统 | Core 有 containment、身份和治理证据，但不是安全认证 |
| 有硬截止时间的批处理逐笔调用远程模型 | 确定性批处理与独立异常审阅，主批不等待审阅 | 同步回调会把模型服务的延迟和故障带进批窗口 |

## 需要你自行构建的部分

内置适配器和示例减少了管道工作。以下能力仍由产品负责，因为它们涉及凭证、持久服务或运营权威：

| 能力 | 你的责任 |
| --- | --- |
| 模型访问 | 适配器选择、凭证、路由、重试、成本策略 |
| 工具 | 工具实现、schema、授权、错误映射 |
| 记忆 | 存储、写入策略、检索、冲突处理、保留、删除 |
| 检索 | 索引、embedding 管线、grounding、新鲜度 |
| 事件与遥测 | Sink 选择、持久化、采样、保留、告警 |
| 策略与身份 | 可信身份、策略决策点、obligation、审计 |
| 审批 | 持久审批存储、最终参数绑定、过期、撤销 |
| 恢复 | checkpoint 存储、lease/fencing、效果账本、对账 |
| 隔离 | provider 选择、隔离验证、网络和资源限制 |
| 运维 | 租户、配额、计费、部署、SLO、事件响应 |

如果这份清单远大于你要解决的问题，更高层框架或托管产品可能更合适。

## 迁移与退出成本

采用 PRAXO-CORE 并不意味着所有层都被同等锁定：

- **Go 公开 API：** 导出的 `pkg/...` 声明遵循[兼容政策](../project/status/compatibility-policy.md)和 API 快照，是最稳定的部分。
- **适配器、示例和产品组装：** 具体适配器和示例不在同等冻结范围内。即使有内置适配器，替换 provider 或 sandbox 仍可能需要适配器工作。
- **语言实现：** Python、TypeScript、Java、Rust、C# 等 Core 共享契约，但不共享 Go 的全部功能。原生适配器和 bridge 会减少工作量，但迁移前仍应核对[语言矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)和 parity 清单，不能假设可以直接替换。
- **Checkpoint 数据：** `pkg/checkpoint` 定义带 JSON 字段的 Go struct。持久化的 checkpoint 数据应按需要评审和迁移的集成格式处理，而不是永久冻结的跨厂商 schema。
- **事件：** `pkg/event` 定义事件信封和 Sink；事件 schema、保留策略和消费者仍由产品负责。
- **安全控制：** policy、审批、sandbox 和身份集成由你运营和验证。迁移意味着替换这些控制，而不只是替换 Agent 循环。

实际退出评估应包含：适配器数量、持久化 checkpoint 和事件兼容性、policy/审批替换、凭证和租户迁移，以及证明行为等价的测试。

## 决策清单

采用前回答：

- 我们是否需要图运行时或持久工作流？如果是，单靠 PRAXO-CORE 不够。
- 我们更需要托管运行时或广泛连接器目录，还是一个小型受治理内核？
- 身份、策略决策、审批和效果账本由谁负责？
- 我们使用哪种语言 Core，其中哪些功能是 partial 或 planned？
- Checkpoint、事件和审计数据存放在哪里，谁可以删除？
- 我们是否已有 sandbox provider，它实际提供什么隔离？
- 我们能否运行所声称的拒绝、取消、恢复和 containment 测试？
- 如果决策改变，移除 PRAXO-CORE 的成本是多少？

## 如果仍然适合

请阅读[采用指南](adoption.md)、运行[快速开始](quickstart.md)，并查看[安全模型](../security/index.md)。跨语言契约证据见[兼容性实验](../languages/compatibility-lab.md)。
