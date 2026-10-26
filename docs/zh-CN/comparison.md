# PRAXO-CORE 与其他 Go Agent 框架的对比

本页将 PRAXO-CORE 与多个常用的 Go Agent 框架进行对比。它是高层定位说明，
不是性能基准。由于 PRAXO-CORE 是 AxisVela 家族的框架层，对比也涵盖与
AxisVela 生态的契合度。内容基于 2026 年 10 月的公开文档；上游项目迭代较快，
采用前请核实最新细节。

| | PRAXO-CORE | LangChainGo | Eino | Google ADK Go | Microsoft Agent Framework Go |
| --- | --- | --- | --- | --- | --- |
| 主要定位 | 面向嵌入的受治理 Agent 运行时基础能力 | LangChain 风格的可组合 LLM 应用 | 带图编排与 ADK 的 LLM 应用框架 | 代码优先的 Agent 工具包，针对 Gemini 优化但模型无关 | 生产级 Agent 与多 Agent 工作流（公开预览） |
| AxisVela 生态 | 为 NOETIVELA、Mnemovela、Harmovela、GNOSIVELA、AEGIVELA、RHEOVELA、LIMENORA 提供一等接缝 | 自定义适配器/工具；无 AxisVela 专用接缝 | 自定义适配器/工具；无 AxisVela 专用接缝 | 自定义适配器/工具；无 AxisVela 专用接缝 | 自定义适配器/工具；无 AxisVela 专用接缝 |
| 编排 | 单 Agent 循环、中间件、子 Agent、`flow` Chain/Parallel | Chains、Agents、Tools | Graph/Workflow、ReAct `ChatModelAgent`、`DeepAgent` 多 Agent | Workflow Agents、图工作流、多 Agent 组合 | 图工作流：顺序、并发、群组、路由、子工作流 |
| 多 Agent | 异步子 Agent 委派（`isolated`/`fork`）；无内置 graph、handoff 或 agent registry | 通过 Agent/Chain 组合 | `DeepAgent` 多 Agent 模式 | 多 Agent 组合与 Workflow Agents | 基于图的多 Agent 工作流 |
| 模型提供商 | 提供商中立的 `model.Model`；NOETIVELA/PRAXOVELA 适配器 | 丰富的内置提供商 | 通过 `eino-ext` 扩展 | Gemini 优先；OpenAI 适配器；模型无关 | Foundry、Azure、OpenAI、Anthropic、Gemini、Copilot |
| 工具与 MCP | 工具契约、JSON Schema、重试、网关；产品所有/LIMENORA 网关；MCP 客户端由使用方提供 | 工具；MCP 非一等支持 | 工具；通过 `eino-ext` 支持 MCP | 丰富工具、MCP Toolset、A2A | 工具、MCP、A2A、AG-UI |
| 记忆与 RAG | 接口与检索契约；Mnemovela 记忆、GNOSIVELA 检索 | Memory、文档加载器、向量存储 | Retriever 与上下文组件 | Sessions、Memory、Artifacts | Memory、文本搜索/RAG、向量存储 |
| 治理与扩展 | 策略钩子、AEGIVELA 策略、路径约束、沙箱接缝、检查点、HITL、进程/WASM 插件平面、事件 Sink | Callbacks | HITL 中断/恢复、Callbacks | 生命周期插件钩子、认证、遥测 | 检查点、工具审批/HITL、OpenTelemetry |
| 许可证 | MIT | MIT | Apache-2.0 | Apache-2.0 | MIT |

## 与 AxisVela 生态的契合度

PRAXO-CORE 是表中唯一按 AxisVela 框架层设计的框架。它提供以下接缝：

- NOETIVELA：受治理的模型路由与推理
- Mnemovela：记忆
- Harmovela：事件与协调
- GNOSIVELA：语义检索与依据
- AEGIVELA：授权
- RHEOVELA：图与工作流执行
- LIMENORA：外部工具、API 与 MCP 网关

这些是契约，不是随框架捆绑的适配器；具体客户端由产品提供。其他框架可以
通过自定义适配器、工具、HTTP 或 MCP 接入 AxisVela，但这些集成不属于它们的
核心契约。参见 [AxisVela 生态集成](12-ecosystem.md)。

## 定位

- **PRAXO-CORE** 刻意保持底层。它不捆绑提供商 SDK、向量数据库或 MCP 客户端。
  其价值在于一个可被产品嵌入的、小型且 MIT 许可的治理与运行时边界，并为
  AxisVela 生态提供一等接缝。
- **LangChainGo** 是 Go 中覆盖面较广的 LangChain 风格实现，提供大量提供商、
  Chains、Memory 后端、文档加载器和向量存储。
- **Eino** 将图/工作流编排与 ADK、ReAct Agent 和多 Agent 模式结合。提供商与
  工具集成主要通过 `eino-ext` 提供。
- **Google ADK Go** 是代码优先的工具包，针对 Gemini 优化，也可用于其他模型。
  它包含 Workflow Agents、图工作流、Sessions、Memory、Artifacts、MCP 工具和
  A2A。
- **Microsoft Agent Framework Go** 面向生产级 Agent 和基于图的多 Agent 工作流，
  提供检查点、HITL、OpenTelemetry、MCP 和 A2A。其 Go 实现处于公开预览阶段。

PRAXO-CORE 在循环层是单 Agent，但支持异步子 Agent 委派。可选模块
`adapters/multiagent` 提供有界的进程内 supervisor 和顺序组合。动态 handoff、
共享状态、图编排与持久恢复仍属于 RHEOVELA 或产品运行时。参见
[多 Agent 模式](13-multi-agent.md)。

## 何时选择 PRAXO-CORE

在需要以下能力时选择 PRAXO-CORE：

- 与 AxisVela 生态的原生接缝：NOETIVELA、Mnemovela、Harmovela、GNOSIVELA、
  AEGIVELA、RHEOVELA 或 LIMENORA
- 可嵌入产品的小型、稳定运行时边界
- 提供商中立的契约，以及由产品拥有的适配器
- 核心内置策略、路径约束、沙箱接缝、检查点和 HITL
- 带一致性测试套件的进程/WASM 插件平面
- 不导入 AGPL 代码的 MIT 许可框架

## 何时选择其他框架

- 需要熟悉的 LangChain 风格 API 和广泛的内置集成时，选择 **LangChainGo**，
  尤其适合 RAG 密集型应用。
- 需要图/工作流编排和成熟的多 Agent ADK 时，选择 **Eino**。
- 需要 Gemini 优先、云原生且具备强大部署和多 Agent 支持的 Agent 工具包时，
  选择 **Google ADK Go**。
- 希望在 Microsoft/Foundry 生态内使用图工作流和检查点时，选择
  **Microsoft Agent Framework Go**。

如果需要深度集成 AxisVela，应优先选择 PRAXO-CORE，而不是在通用框架上额外
叠加产品专用适配器。

## 说明

本对比不评估性能、稳定性或生态成熟度。功能描述依据各项目的公开文档，可能
滞后于最新版本。如果某项对比已过时，欢迎提交 issue。
