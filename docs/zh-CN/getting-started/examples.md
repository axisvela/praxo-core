# 示例目录

先按任务选择示例，再按语言查找。Go 参考示例和跨语言示例位于仓库
[`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples)
目录；语言专属示例位于 `language/<language>/examples/`，会进入对应语言的
发现镜像仓库。

## 按任务选择

| 任务 | 示例 | 说明 |
| --- | --- | --- |
| 连接真实模型 | [真实模型 Golden Path](live-model-golden-path.md) | 发布包、OpenAI-compatible 端点、一个 `get_time` 工具 |
| 连接其他 Provider 或 MCP | [Provider 与 MCP 演练](../guides/provider-walkthrough.md)、[MCP 教程](../guides/mcp-tutorial.md) | 发布包 Adapter、本地 MCP 客户端与 Transport 边界 |
| 增加 Provider fallback | [`language/python/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/provider-fallback)、[`language/typescript/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/provider-fallback)、[`language/csharp/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/provider-fallback)、[`language/rust/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/provider-fallback) | 主模型失败后切换备用模型；确定性测试 |
| 验证安装与拒绝路径 | [消费者 Starter](index.md) | 发布包安装与确定性 allow/deny 检查 |
| 生成受校验 JSON | [结构化输出教程](../guides/structured-output-tutorial.md) | Python、TypeScript、Java、C# 的 `StructuredOutput` 与确定性 fake-model 测试 |
| 构建 Workspace Agent | [Workspace Agent 教程](../guides/workspace-agent-tutorial.md) | 使用发布包的只读 Go 应用 |
| 嵌入应用 | [应用嵌入清单](../guides/application-integration-checklist.md) | 只读、有副作用、高风险部署的分档清单 |
| 通过 HTTP 运行 Core | [HTTP 嵌入服务教程](../guides/embedded-service-tutorial.md)、[`examples/embedded-service-auth`](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth)、[`language/python/examples/service`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service) | Go/Python 服务，以及 HMAC token 与租户策略变体 |
| 查看 Go 参考应用 | [`examples/reference`](https://github.com/axisvela/praxo-core/tree/main/examples/reference) | Go 参考应用 |
| 增加 Policy 与审批 | [`examples/governed-workspace`](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace) | Go 受治理执行边界示例 |
| 增加 Checkpoint | [`examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/examples/checkpoint) | Go Checkpoint 存储示例 |
| 增加 Plugin | [`examples/plugin`](https://github.com/axisvela/praxo-core/tree/main/examples/plugin) | Go 进程/WASM Plugin Host 示例 |
| 委派任务 | [`examples/multiagent`](https://github.com/axisvela/praxo-core/tree/main/examples/multiagent) | Go 本地委派示例 |
| 使用专题配方 | [`examples/recipes`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes) | Go Provider、事件、重试、VFS 等配方 |
| 集成生态组件 | [`examples/ecosystem`](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem) | 可选 AxisVela Adapter 结构 |

## 示例与配方

- [`examples/recipes`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes)
  是 Go 为主的复制粘贴配方，并提供局部测试证据。
- `examples/` 是可运行项目，包括发布包和语言专属集成。

结构化输出、Checkpoint 存储、身份、VFS 隔离和长时操作等主题会同时出现在两种形式中。
配方用于理解机制，示例用于应用形态集成；不要把两者同时复制进一个项目。

## 按语言选择

| 语言 | 示例 |
| --- | --- |
| Go | [`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples) |
| Python | [`language/python/examples`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples) |
| TypeScript | [`language/typescript/examples`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples) |
| Java | [`language/java/examples`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples) |
| C# | [`language/csharp/examples`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples) |
| Rust | [`language/rust/examples`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples) |
| Ruby | [`language/ruby/examples`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples) |
| PHP | [`language/php/examples`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples) |
| Elixir | [`language/elixir/examples`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples) |
| Lua | [`language/lua/examples`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples) |

每个语言示例目录都有自己的 README，包含安装和运行命令。Python、TypeScript、
Java、Rust、C# 等 Core 实现独立版本化；当前支持范围见
[语言总表](../languages/matrix.md)。

## 组织方式

- `examples/` 放置 Go 参考示例和跨语言集成。
- `language/<language>/examples/` 放置语言专属可运行示例。
- 语言示例会复制到对应发现镜像仓库。
- 使用已发布包的示例不要求检出仓库或替换本地包。

示例不是生产安全 Profile。身份、持久审批、效果对账和隔离仍由应用负责。
