# PRAXO-CORE 架构

## 分层

```text
Agent 循环
  -> 模型抽象
  -> 工具注册表
  -> 运行时插件平面（Manifest、宿主、桥接、TCK）
  -> 策略钩子
  -> 事件 Sink
  -> 记忆存储
  -> 检查点存储
  -> 沙箱
  -> 调度器契约
  -> HTTP 客户端
```

Agent 循环仅依赖其所需的接口。插件宿主、HTTP 客户端、调度器和沙箱是由产品
或外部集成方提供的适配器。

## Agent 循环

1. 启动运行，应用运行中间件，并发出 `run.started`。
2. 从系统提示词、召回的记忆、技能、会话消息和用户提示词构建提示词。
3. 每一步：
   - 授权模型生成；
   - 配置了 `ContextBudget` 时压缩提示词；
   - 运行模型中间件并在重试机制下调用模型；
   - 强制执行 token 预算；
   - 追加助手消息。
4. 如果模型请求工具：
   - 授权每个工具调用；
   - 运行审批/中断处理和工具中间件；
   - 调用工具（可选并行）并追加结果；
   - 发出工具事件并继续。
5. 得到最终答案时，写入记忆记录，发出 `run.completed`，然后返回。
6. 策略拒绝时失败关闭。
7. 在 `MaxSteps`、`MaxTokens` 或 `ErrContextBudget` 处停止。

## 上下文管理

上下文按层管理：

- `Options.MemoryFiles` 在构造时将 `AGENTS.md` 内容加载到系统提示词中，受
  `MaxAgentsMDBytes` 限制。
- `ContextBudget` 确定性地将最近轮次和工具调用/结果对保持在估算的 token
  上限内。
- `ContextCompactor` 可以在确定性处理之前摘要较早的轮次；`ModelSummarizer`
  是内置的基于模型的实现。
- `Offloader` 在工具结果进入提示词之前，将超过
  `OffloadThresholdBytes` 的结果替换为调用方拥有的引用。
- `Options.PromptCache` 为稳定前缀提供提供商中立的 `model.CacheHint`；
  提供商可以将其转换为自己的缓存控制机制。

压缩和卸载可通过 `Hooks.OnCompaction` 和 `Hooks.OnOffload` 观察。

## Harness 配置与评估

- `model.ProviderProfile`/`ProfileRegistry` 按模型前缀描述上下文窗口、输出
  限制、工具/流/缓存支持和工具调用格式。
- `agent.RubricMiddleware` 使用 `Evaluator` 评估已完成的运行，并在低于
  `Rubric.PassScore` 时使运行失败。
- `sandbox.Interpreter` 是可选的进程内脚本接缝；产品在需要时提供运行时
  （例如 QuickJS）。

## Agent 包布局

- `pkg/agent` 保留 `Agent`、`Options`、`New`、`Run` 和兼容别名。
- 能力子包：`types`、`context`、`delegation`、`evaluation`、`hitl`、
  `stream` 和 `middleware`。
- 根包别名保持 `agent.*` 源码兼容；新能力位于对应的子包。

## Agent 中间件对齐

- `StructuredOutput` 通过提供商响应格式或虚拟工具绑定 JSON schema，校验
  最终输出，并可选择修复。
- `ToolSelectionMiddleware` 按运行缩小对外公布的工具有范围；
  `ModelToolSelector` 是内置的基于模型的选择器。
- `PIIMiddleware` 在发往模型的消息和工具结果进入提示词之前进行脱敏。
- `FallbackModel` 在主模型调用失败时重试回退模型。
- `CallLimitMiddleware` 限制每次运行的模型和工具调用次数。
- `ContextEditingMiddleware` 清除旧工具结果而不丢弃消息对。
- `TodoTool`/`TodoMiddleware` 提供 `write_todos` 规划状态和提示词注入。
- `pkg/tool.Retry` 使用相同策略形态重试失败的工具调用。

## 人在回路决策

- `InterruptDecision` 支持批准、编辑、拒绝和回复。
- `Options.OnInterruptDecision` 优先于旧的布尔 `OnInterrupt`；编辑会替换工具
  参数，回复会跳过执行并将人类回复反馈给模型。
- Shell 会话、执行策略和 MCP 引导仍由产品/Janus 负责；核心只拥有决策契约。

## 运行时互操作性

- `OnStream` 发出类型化 `StreamPart` 投影：值、更新、消息、任务、调试和
  检查点。
- 流使用方可以持久化或转发投影，而无需解析事件 Sink。
- 会话级恢复通过预先填充 `Session.Messages` 表达；持久化检查点存储仍属于
  产品关注点。
- 图执行仍归 RHEOVELA 所有；核心流是 Agent 节点边界，而不是
  LangGraph 兼容的投影运行时。

## 委派

- `SubagentManager` 异步运行委派的子任务，支持启动/检查/等待/更新/取消/
  列表/清理。
- `SubagentIsolated` 仅携带请求上下文启动子 Agent；`SubagentFork` 携带父
  消息历史。
- 实现 `ControllableRunner` 的运行器可以接受运行中的转向指令。
- `Cancel` 不改变终态任务；`Update` 只接受运行中的任务。

## 虚拟文件系统

- `pkg/vfs` 定义后端契约（`Stat`、`Read`、`Write`、`List`、`Delete`、
  `Glob`、`Grep`）和可选的 `Executor`。
- `pkg/vfs/localfs` 将所有路径限制在一个根目录内，并拒绝遍历、同级前缀和
  符号链接逃逸。
- `pkg/vfs/vfstools` 将后端暴露为 Agent 循环的 `fs.*` 工具。

## 插件平面

插件平面在契约边界处拆分：

- `pkg/plugin` 拥有 Manifest v1、契约类型、生命周期、受保护注册表、作用域、
  限制和遥测。
- `pkg/plugin/host/{process,wasm}` 拥有宿主实现和平台监督器。
- `pkg/plugin/bridge` 将宿主映射到 `tool.Tool`、`model.Model`、
  `policy.Hook`、`memory.Store` 和 `sandbox.Sandbox`。
- `pkg/plugin/tck` 断言生命周期、注册表、分帧、超时、取消、能力拒绝和
  非活跃门禁。

产品拥有物化、签名信任、SBOM/证据和滚动更新。框架从不导入产品治理代码。

## 设计规则

- 接口优先；具体集成是适配器。
- 框架中不存放提供商凭据。
- 日志中不包含租户数据。
- 不导入 AGPL 代码。
- 每个导出的行为都有测试。
- 事件和策略错误会向上传播；不会被静默丢弃。

## 语言边界与共享契约

Go 保留为参考实现。Python、TypeScript 和 Java 消费的契约定义在 `spec/` 中，并由
共享一致性套件强制执行：

```text
spec/                    规范契约与向量
  wire/                  JSON 字段名、事件、错误、插件信封
  vectors/               语言无关的行为夹具
  parity.md              Go 符号 -> SDK 符号清单
        |
        +-- Go 参考实现（pkg/...，表面不可变）
        +-- Python SDK
        +-- TypeScript SDK
        +-- Java SDK
```

契约分四层：

| 层 | 跨语言是否相同 | 强制执行方式 |
| --- | --- | --- |
| 线格式 | 是，逐字节一致 | wire 夹具与快照测试 |
| 行为 | 是，可观察一致 | 一致性向量 |
| API 表面 | 一对一，名称符合语言习惯 | 一致性 linter |
| 一致性 | 同一套件 | 每个 SDK 的 CI 任务 |

源码 API 是映射而非照搬。Go 接口变成 Python protocol、TypeScript interface 和
Java interface；`context.Context` 变成语言的取消原语；sentinel 错误变成稳定异常
类。具体适配器、辅助函数和包内部实现不属于契约。

wire 改名、事件变更、stream kind 变更或插件信封变更对所有 SDK 都是破坏性变更，
即使只有一个 SDK 发布。参见[多语言 SDK 设计](17-multilingual-sdk.md)和
[多语言路线图](18-multilingual-roadmap.md)。

## 并发

框架按运行无状态。调用方可以并发运行多个 Agent。共享适配器必须自行提供
同步。当 `MaxParallelTools > 1` 时，一次模型响应中的工具调用可以并发执行，
同时保持消息顺序。
