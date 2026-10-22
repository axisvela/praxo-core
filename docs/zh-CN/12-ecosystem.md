# AxisVela 生态集成

PRAXO-CORE 是 AxisVela Agent 共享的框架层。它暴露中立的契约，使每个生态组件
都能提供适配器，而无需修改 Agent 循环。

## 集成映射

| 生态组件 | PRAXO-CORE 接缝 | 典型适配器 |
| --- | --- | --- |
| 模型 | `pkg/model`（`Model`、`Provider`、`ProviderProfile`） | PRAXOVELA 提供商路由器 / 使用方适配器 |
| 记忆 | `pkg/memory`（`Store`、`ContextAssembler`） | Mnemovela |
| 事件 | `pkg/event`（`Sink`、`PublisherSink`） | Harmovela / Argus Trace |
| 检索 | `pkg/retriever`（`Retriever`、`Document`） | GNOSIVELA / Mnemovela |
| 策略 | `pkg/policy`（`Hook`、`PathChecker`） | AEGIVELA / Archon Guard |
| 沙箱 | `pkg/sandbox`（`Sandbox`、`Interpreter`） | Vulcan Forge |
| 工具 | `pkg/tool`（`Tool`、`Gateway`） | Janus Gateway |
| 图执行 | `pkg/agent`、`pkg/agent/stream` | RHEOVELA |
| 产品运行时 | 所有接口 | PRAXOVELA |

## 接缝如何工作

- **模型。** 实现 `model.Model`，或适配现有的提供商路由器。
  `model.ProviderProfile` 按模型前缀描述上下文、输出、工具、流和缓存能力。
- **记忆。** 实现 `memory.Store` 以支持会话、工作区或长期记忆。Mnemovela
  提供产品侧的存储实现。
- **事件。** 实现 `event.Sink`，将生命周期事实发布到 Harmovela。相同事件
  也可以持久化到 Argus Trace。
- **检索。** 实现 `retriever.Retriever`；GNOSIVELA 和 Mnemovela 可以提供
  文档与上下文。
- **策略。** 实现 `policy.Hook` 进行授权；AEGIVELA 和 Archon Guard 在此
  接入。`policy.PathChecker` 提供内置路径约束。
- **沙箱。** 实现 `sandbox.Sandbox` 以隔离命令执行；Vulcan Forge 提供产品侧
  隔离实现。
- **工具。** 注册 `tool.Tool`。Janus Gateway 通过 `tool.Gateway` 暴露产品
  拥有的外部工具。
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
