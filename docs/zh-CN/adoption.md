# 采用指南

本指南面向评估或集成 PRAXO-CORE 的团队，涵盖评估路径、最小原型、生产检查
清单和常见陷阱。

## 1. 评估

在需要以下能力时，PRAXO-CORE 是合适的选择：

- 具有明确策略、沙箱、检查点、记忆和事件边界的受治理 Agent 循环
- 提供商中立的契约，以及由产品拥有的适配器
- 可嵌入且不产生 AGPL 义务的 MIT 许可框架
- AxisVela 生态的一等接缝

它不是托管式 Agent 服务、模型提供商、向量数据库或开箱即用的聊天 UI。

## 2. 构建 30 分钟原型

1. 添加模块：

   ```bash
   go get github.com/axisvela/praxo-core/v2@v2.5.0
   ```

2. 使用 OpenAI 兼容适配器连接 Ollama 或托管端点：

   ```go
   adapter := openaicompat.Adapter{
       BaseURL: "http://localhost:11434/v1",
       Model:   "llama3.2",
   }
   ```

3. 注册一个工具并创建 Agent：

   ```go
   tools := tool.NewRegistry()
   tools.Register(myTool{})

   ag, err := agent.New(agent.Options{
       Model:    adapter,
       Tools:    tools,
       MaxSteps: 4,
       Policy:   policy.FuncHook(allow),
       Events:   event.FuncSink(logEvent),
   })
   ```

4. 运行会话：

   ```go
   result, err := ag.Run(ctx, agent.Session{
       ID:          "demo",
       TenantID:    "local",
       WorkspaceID: "default",
   }, "Inspect the workspace and summarize it.")
   ```

可运行版本参见 [快速开始](quickstart.md) 和 [Recipes](recipes.md)。

## 3. 映射集成点

| 需求 | 接缝 | 起点 |
| --- | --- | --- |
| 模型访问 | `pkg/model` | `adapters/openaicompat`、NOETIVELA SDK 示例 |
| 记忆 | `pkg/memory` | `memory.MemoryStore`、Mnemovela SDK 示例 |
| 检索 | `pkg/retriever` | GNOSIVELA SDK 示例 |
| 工具 | `pkg/tool` | `tool.Registry`、`tool.Gateway`、MCP 适配器 |
| 事件 | `pkg/event` | `event.Sink`、Harmovela publisher |
| 授权 | `pkg/policy` | `policy.Hook`、AEGIVELA |
| 执行 | `pkg/sandbox` | `sandbox.Sandbox`、产品沙箱 |
| 文件 | `pkg/vfs` | `localfs`、`vfstools` |
| 持久化 | `pkg/checkpoint` | 产品拥有的检查点存储 |

## 4. 生产检查清单

- 将提供商凭据、租户策略和信任根放在框架之外。
- 策略默认失败关闭，并测试拒绝路径。
- 将 shell 或网络执行放在沙箱之后。
- 对长时间运行或有副作用的运行持久化检查点。
- 将事件转发到可观测性管线。
- 启动插件宿主前验证签名、SBOM 和信任。
- 固定框架版本，并运行 [兼容性](05-compatibility.md) 中的检查。
- 在 CI 中运行 `GOWORK=off go test -race ./...`。
- 跟踪 [基准测试](benchmarks.md) 以检测回归。

## 5. 迁移说明

- 从 LangChainGo、Eino 或 ADK 迁移时，映射概念而不是复制代码。PRAXO-CORE
  将循环、提供商抽象、工具、记忆、事件、策略和插件拆分为独立契约。
- v1 使用方应遵循 [v2 迁移指南](11-migration-v2.md)。
- 如果需要 AxisVela 集成，应优先使用 [生态指南](12-ecosystem.md)，而不是
  在通用框架上叠加产品专用代码。

## 6. 常见陷阱

- **`model.Request.Model` 为空。** Agent 不会设置该字段。应从适配器状态、
  运行上下文或消息中推导提供商或契约配置。
- **NOETIVELA SDK 只支持文本。** 其 `ChatResponse` 不暴露工具调用。需要工具
  调用时应使用自定义 HTTP 适配器。
- **MCP 认证绑定在会话上。** MCP 适配器会忽略 `tool.Gateway.Execute` 的
  token 参数。
- **MCP 工具列表有缓存。** 服务器工具变化后调用 `Refresh`。
- **GNOSIVELA 尚无 `v3` semver 标签。** 示例固定 pseudo-version。
- **VFS 约束是检查后使用。** 高风险工作负载应增加操作系统级约束。

## 7. 下一步

- [快速开始](quickstart.md)
- [Recipes](recipes.md)
- [AxisVela 生态](12-ecosystem.md)
- [对比](comparison.md)
- [安全模型](08-security.md)
- [Reference workspace agent](https://github.com/axisvela/praxo-core/tree/main/examples/reference)
