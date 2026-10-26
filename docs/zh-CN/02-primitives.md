# PRAXO-CORE 基础能力

| 包 | 契约 | 典型适配器 |
| --- | --- | --- |
| `pkg/model` | `Model.Generate`、`Provider.Chat/ChatStream`、`ModelRouter`、`ChatModel`、`CacheHint`、`ProviderProfile` | PRAXOVELA 提供商路由器 |
| `pkg/agent` | `Agent.Run`、`Options`、`New`、兼容别名 | PRAXOVELA Agent 循环 |
| `pkg/agent/context` | 预算、压缩、摘要、卸载、`AGENTS.md` | PRAXOVELA 上下文管理 |
| `pkg/agent/delegation` | `SubagentManager` 与模式 | PRAXOVELA 子 Agent |
| `pkg/agent/evaluation` | `Rubric`、`Evaluator`、`RubricMiddleware` | PRAXOVELA 评估 |
| `pkg/agent/hitl` | `InterruptDecision` 与处理器 | PRAXOVELA 审批 |
| `pkg/agent/middleware` | 调用限制、回退、PII、结构化输出、工具选择 | PRAXOVELA 中间件 |
| `pkg/agent/stream` | 类型化 `StreamPart` 投影 | PRAXOVELA 流式输出 |
| `pkg/agent/types` | 共享运行状态契约 | 框架使用方 |
| `pkg/checkpoint` | `Checkpoint`、`Store.Save/Load/List`、恢复报告 | PRAXOVELA 检查点存储 |
| `pkg/httpclient` | 支持重试、带认证、追踪与解码的 HTTP 传输层 | PRAXOVELA 适配器 |
| `pkg/tool` | `Tool`、`Registry`、`SpecProvider`、`Middleware`、`Retry`、`Gateway` | 产品工具网关 |
| `pkg/memory` | `Store.Put/Search`、`MemoryStore`、`ContextAssembler`、`RemoteStore` | Mnemovela |
| `pkg/event` | `Sink.Emit`、`MultiSink`、`FilterSink`、`PublisherSink` | Harmovela / 产品事件存储 |
| `pkg/policy` | `Hook.Authorize`、`PathChecker` 读写约束 | AEGIVELA / 产品策略引擎 |
| `pkg/sandbox` | `Sandbox.Run`、可选 `Interpreter.Eval` | 产品沙箱 |
| `pkg/scheduler` | `Scheduler.Add/Remove/List`；从 PRAXOVELA 提取的 cron 引擎 | PRAXOVELA 持久化调度器 |
| `pkg/toolcall` | `ParseToolCall`、`StripToolCallMarkup`、`ParseInputJSON` | 模型输出解析 |
| `pkg/tool/jsonschema` | 最小 JSON Schema 子集校验 | 工具输入/输出校验；不是完整校验器 |
| `pkg/flow` | `Runnable`、`Chain`、`Parallel` | 提示词/Agent 组合 |
| `pkg/prompt` | `Template`、`ChatTemplate` | 提示词组装 |
| `pkg/retriever` | `Document`、`Retriever` | Mnemovela/GNOSIVELA 检索 |
| `pkg/formatter` | 代码格式化器注册表 | PRAXOVELA 格式化工具 |
| `pkg/vfs` | `Backend`、受限本地后端、文件系统工具 | PRAXOVELA 文件工具 |
| `pkg/plugin` | Manifest v1、契约类型、`Host.Invoke`、`Lifecycle`、`AdapterRegistry` | PRAXOVELA 运行时插件平面 |
| `pkg/plugin/host/process` | 进程宿主、平台监督器、JSON-Lines 信封 | PRAXOVELA 进程插件 |
| `pkg/plugin/host/wasm` | 基于 wazero 的 WASM 宿主 | PRAXOVELA WASM 插件 |
| `pkg/plugin/bridge` | 从 `Host` 到 `tool`/`model`/`policy`/`memory`/`sandbox` 的适配器 | 框架使用方 |
| `pkg/plugin/tck` | 生命周期、注册表与宿主一致性断言 | 宿主/提供商实现者 |

`pkg/toolcall` 存放模型输出中的工具调用解析。`pkg/output`、`pkg/format` 和
`pkg/tool/schema` 是已在 `1.0.0` 中移除的废弃别名；新代码应导入
`pkg/toolcall`、`pkg/formatter` 和 `pkg/tool/jsonschema`。

`pkg/tool/jsonschema` 支持 `type`（object、array、string、number、integer、
boolean）、`properties`、`required`、`items`、`enum`、`minLength`、`maxLength`、
`minimum`、`maximum`、`pattern`（Go/RE2）和 `description`。不支持的关键字会被
忽略，包括 `$ref`、`allOf`、`anyOf`、`oneOf`、`not`、`additionalProperties`
和 `format`；`minimum` 或 `maximum` 为 0 时视为未设置。需要这些关键字时应使用
完整 JSON Schema 库。

Manifest v1、进程/WASM 宿主协议以及一致性测试套件参见
[插件编写](10-plugin-authoring.md)。

## 语言无关契约

`pkg/...` 中的 Go 声明是参考表面。所有 SDK 的规范契约位于 `spec/`：

- `spec/wire/` 冻结 JSON 字段名、事件、错误和插件信封。
- `spec/vectors/` 定义每个 SDK 必须复现的可观察行为。
- `spec/parity.md` 将每个 Go 符号映射到 Python、TypeScript 和 Java 对应符号。

wire 名称保留现有大小写，包括 `model.ContentBlock` 中的 `image_url` 以及
`runId` 等 camelCase 标识符。源码 API 按语言惯例实现，但保持一对一映射。参见
[多语言 SDK 设计](17-multilingual-sdk.md)。

## 工具契约

工具包含名称、描述和 `Invoke(ctx, args)`。工具规格通过注册表暴露给模型。
参数是 JSON 兼容的 map。

## 记忆契约

记忆按帧类型化：事件、决策、经验、过程、工作区状态、约束、意图。框架不规定
保留或准入策略；由适配器决定。

## 事件契约

事件是生命周期事实，不是日志。使用方可以将它们发布到 Harmovela 或持久化到
产品事件存储。

## 策略契约

每次模型生成和工具调用都可以被授权。拒绝时默认失败关闭。框架不实现策略；
它执行钩子的结果。

## 调度器契约

框架定义调度。运行时负责持久化触发和执行。调度契约有意与 Agent 循环分离。
