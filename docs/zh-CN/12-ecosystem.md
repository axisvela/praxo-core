# AxisVela 生态集成

PRAXO-CORE 是 AxisVela Agent 共享的框架层。它暴露中立的契约，使生态组件
能够在不修改 Agent 循环的情况下提供适配器。大多数 AxisVela 公开仓库通过
四种方式之一集成：核心运行时接缝、工具或网关、事件/协调协议，或产品运行时
适配器。

## 核心集成映射

| 生态组件 | PRAXO-CORE 接缝 | 典型适配器 |
| --- | --- | --- |
| 模型与推理路由 | `pkg/model`（`Model`、`Provider`、`ModelRouter`、`ProviderProfile`） | [NOETIVELA](https://github.com/axisvela/noetivela-open) / PRAXOVELA 提供商路由器 |
| 记忆 | `pkg/memory`（`Store`、`ContextAssembler`） | [Mnemovela](https://github.com/axisvela/mnemovela-open) |
| 事件 | `pkg/event`（`Sink`、`PublisherSink`） | [Harmovela](https://github.com/axisvela/harmovela) / Argus Trace |
| 检索 | `pkg/retriever`（`Retriever`、`Document`） | [GNOSIVELA](https://github.com/axisvela/gnosivela-open) / Mnemovela |
| 策略 | `pkg/policy`（`Hook`、`PathChecker`） | [AEGIVELA](https://github.com/axisvela/aegivela-open) / Archon Guard |
| 沙箱 | `pkg/sandbox`（`Sandbox`、`Interpreter`） | Vulcan Forge |
| 工具 | `pkg/tool`（`Tool`、`Gateway`） | Janus Gateway / [LIMENORA](https://github.com/axisvela/limenora-open) |
| 图执行 | `pkg/agent`、`pkg/agent/stream` | [RHEOVELA](https://github.com/axisvela/rheovela-open) |
| 产品运行时 | 所有接口 | [PRAXOVELA](https://github.com/axisvela/praxovela-open) |

适配器骨架：[`examples/ecosystem`](../../examples/ecosystem)。

## NOETIVELA 与模型路由

可以。[NOETIVELA](https://github.com/axisvela/noetivela-open) 是 AxisVela 的
推理基础设施（inference fabric），可以接入模型接缝。

- 将 NOETIVELA 的受治理 Chat API 包装为 `model.Model` 或 `model.Provider`；
  `model.ChatModel` 可以把 `Provider` 适配为 `Model`。
- 在适配器内将中立的 `model.Request` 映射为 NOETIVELA Inference Contract。
  task、modality、region、数据分类等契约字段属于适配器或产品配置；核心
  请求不会新增 NOETIVELA 专用字段。
- 需要按端点描述上下文、输出、工具、流或缓存能力时，使用
  `model.ProviderProfile`。
- 框架不内置 NOETIVELA Go SDK 或提供商凭据。`noetivela-open` 采用
  Apache-2.0，可由适配器或产品导入。
- `ecosystem.Model` 和 `ecosystem.Provider` 骨架展示了适配器可以填充的
  回调形态。

## 其他 AxisVela 组件

这些组件不是核心 Agent 循环的基础能力，但可以通过工具、事件、策略输入或
产品运行时适配器接入。可浏览
[当前公开仓库列表](https://github.com/orgs/axisvela/repositories?q=visibility%3Apublic+archived%3Afalse)。

| 组件 | 公开仓库 | 集成方式 |
| --- | --- | --- |
| EIDOVELA | [eidovela-open](https://github.com/axisvela/eidovela-open) | Agent 身份；产品运行时或策略输入 |
| NOMIVELA | [NOMIVELA-open](https://github.com/axisvela/NOMIVELA-open) | Agent 注册表与命名空间；产品运行时或工具发现 |
| SYMBIVELA | [symbivela-open](https://github.com/axisvela/symbivela-open) | 人工审批与干预；HITL 决策或产品 UI |
| TEKMOVELA | [tekmovela-open](https://github.com/axisvela/tekmovela-open) | 验证与保障；工具或发布门禁 |
| MODUREGIS | [moduregis-open](https://github.com/axisvela/moduregis-open) | 能力注册表；`tool.Registry` 或 `tool.Gateway` |
| SYNDOVELA | [SYNDOVELA-open](https://github.com/axisvela/SYNDOVELA-open) | 技能组合；产品加载的工具或技能 |
| ONTOVELA | [ontovela-open](https://github.com/axisvela/ontovela-open) | 数字孪生与世界模型；工具或检索 |
| ORCHADYN | [orchadyn-open](https://github.com/axisvela/orchadyn-open) | 能力规划；工具或产品编排 |
| COORDIVELA | [coordivela-open](https://github.com/axisvela/coordivela-open) | 开发协调；事件、工具或产品集成 |
| KINETOVELA | [kinetovela-open](https://github.com/axisvela/kinetovela-open) | 机器人集群执行；工具、沙箱或产品集成 |
| PEIRAVELA | [peiravela-open](https://github.com/axisvela/peiravela-open) | 实验控制；工具或产品集成 |

## 核心接缝如何工作

- **模型。** 实现 `model.Model`，或适配现有的提供商路由器。
  `model.ProviderProfile` 按模型前缀描述上下文、输出、工具、流和缓存能力。
- **记忆。** 实现 `memory.Store` 以支持会话、工作区或长期记忆。
- **事件。** 实现 `event.Sink`，将生命周期事实发布到 Harmovela。相同事件
  也可以持久化到 Argus Trace。
- **检索。** 实现 `retriever.Retriever`；GNOSIVELA 和 Mnemovela 可以提供
  文档、语义依据和上下文。
- **策略。** 实现 `policy.Hook` 进行授权；AEGIVELA 和 Archon Guard 在此
  接入。`policy.PathChecker` 提供内置路径约束。
- **沙箱。** 实现 `sandbox.Sandbox` 以隔离命令执行；Vulcan Forge 提供产品侧
  隔离实现。
- **工具。** 注册 `tool.Tool`。Janus Gateway 和 LIMENORA 通过
  `tool.Gateway` 暴露产品拥有的外部工具。
- **图执行。** RHEOVELA 拥有图与子图执行。PRAXO-CORE 暴露 Agent 节点、
  会话和流边界。
- **插件。** `pkg/plugin/bridge` 将运行时插件宿主映射到工具、模型、策略、
  记忆和沙箱契约。

## 边界

- 接口和线格式契约位于 MIT 框架中。
- 具体适配器、凭据、租户策略、信任存储、SBOM/证据和插件物化归产品所有。
- 框架不导入产品代码，也不捆绑提供商 SDK、向量数据库或 MCP 客户端。
- 本仓库列出的是集成接缝，而不是已随框架发布的适配器。产品实现可以位于
  PRAXOVELA 或其他 AxisVela 仓库。
