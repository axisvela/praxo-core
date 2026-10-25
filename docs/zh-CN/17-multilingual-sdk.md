# 多语言 SDK 设计

**状态：**`2.x` 系列的设计承诺，2026-10-25。本文定义 Python、TypeScript 和
Java SDK 共享的契约、仓库布局、命名规则与一致性模型，不改变任何已导出的 Go
声明。

## 背景

Go 适合作为参考运行时：接口明确、并发成本低、依赖面小。但应用团队主要使用
Python 和 TypeScript，企业集成方常要求 Java。框架应当服务这些团队，而不是把
契约分叉成三个互不兼容的产品。

目标是**一份契约、四个符合各自语言习惯的实现**：

- Go 保留为参考实现和行为事实来源。
- Python、TypeScript、Java SDK 实现同一份契约。
- 语言无关的规范与一致性套件定义“同一份”的含义。
- SDK 之间没有运行时依赖。

## 非目标

- 重写或废弃 Go 模块。
- 生成一套在每种语言里都很别扭的 API。
- 在任一 SDK 中打包提供商 SDK、向量数据库或产品治理。
- 跨语言 FFI、共享进程内状态或多语言运行时。
- 逐字节相同的源码 API；只有契约相同。

## 契约分层

契约分四层。只有第一层要求线格式完全一致，其余层要求可观察行为等价。

| 层 | 内容 | 跨语言规则 |
| --- | --- | --- |
| 线格式 | JSON 字段名与大小写、事件类型、stream kind、插件 Manifest v1 与宿主信封、错误码、JSON Schema 子集 | 逐字节一致；改名即破坏性变更 |
| 行为 | Agent 循环顺序、策略拒绝时失败关闭、事件顺序、重试/退避、token 估算、确定性压缩、并行工具保序 | 必须通过同一组一致性向量 |
| API 表面 | 接口、选项字段、结果类型、中间件边界 | 一对一映射，名称符合语言习惯 |
| 一致性 | 向量、夹具、期望事件与错误 | 一套套件，每个 SDK 在 CI 中执行 |

当规范与 Go 实现不一致时，视为缺陷。规范是规范性的，Go 是用于发现和验证规范的
参考实现。

### 线格式层

线格式名称按现状冻结。当前契约本身混用大小写：

- `model.ContentBlock` 的 `image_url` 是 snake_case。
- `tenantId`、`workspaceId`、`runId`、`sessionId` 是 camelCase。
- 事件负载键记录在[事件 schema](event-schema.md)中。

多语言 SDK 必须保留这种精确的混用。任一 SDK 自行规范化名称都属于破坏性线格式
变更，即使看起来更整洁。

线格式层还包括：

- 事件类型字符串与 stream kind
- 插件 Manifest v1、契约类型、生命周期状态、进程 JSON-Lines 信封和 WASM guest ABI
- 错误码与 sentinel
- 文档化的 JSON Schema 子集及其忽略的关键字
- 工具调用解析标记

### 行为层

行为一致性通过向量而非文字验证。必需的向量组：

| 组 | 必需断言 |
| --- | --- |
| `agent-loop` | 事件顺序、步数预算、最大 token、最终回答、拒绝时失败关闭 |
| `toolcall` | 解析、标记剥离、畸形输入、幂等键透传 |
| `jsonschema` | 接受/拒绝输入、忽略的关键字、Unicode 长度规则 |
| `memory` | frame 类型、召回顺序、上下文组装 |
| `checkpoint` | 保存/加载/列表往返、allowlist 行为 |
| `policy` | 路径约束、拒绝传播 |
| `stream` | stream kind 顺序与负载形状 |
| `plugin` | Manifest 校验、生命周期转换、信封分帧 |

并发、取消和错误映射属于行为层，但通过各语言专用测试装置消费同一份夹具来断言。

### API 表面层

映射是一对一，而不是名称相同：

| Go | Python | TypeScript | Java |
| --- | --- | --- | --- |
| `model.Model` | `praxo.model.Model`（`Protocol`） | `Model`（`interface`） | `Model`（`interface`） |
| `model.Request` | `praxo.model.Request`（`dataclass`） | `Request`（`interface`） | `Request`（`record`） |
| `agent.Options` | `praxo.agent.Options`（`dataclass`） | `AgentOptions`（`interface`） | `AgentOptions`（`builder`） |
| `agent.New(Options)` | `praxo.agent.Agent(options)` | `new Agent(options)` | `Agent.create(options)` |
| `context.Context` | `contextvars` + 任务取消 | `AbortSignal` | 取消令牌 |
| `error` sentinel | 异常类 | `Error` 子类 | 异常类 |
| `tool.Tool` | `praxo.tool.Tool` | `Tool` | `Tool` |

规则：

- Go `Options` 字段变成可选关键字参数，默认值保持不变。
- Go sentinel 错误变成稳定异常类，并携带相同错误码。
- Go `context.Context` 变成语言的取消原语，绝不退化为普通超时参数。
- Go 接口变成方法语义相同的 protocol/interface。
- Go 具体适配器不属于契约，可按语言差异实现。

### 一致性层

`spec/vectors` 是“同一份契约”的唯一可执行定义。每个 SDK 提供 runner 和 CI 任务，
执行全部向量，并在首次行为分歧处失败。先构建 Go runner，用它证明向量正确，再由
其他语言消费。

## 事实来源

```text
spec/                     规范契约与向量
  SPEC_VERSION            契约版本，独立于 SDK 版本
  parity.md               Go 符号 -> Python/TS/Java 符号清单
  wire/                   JSON 信封、事件、错误、插件契约
  vectors/                语言无关的行为夹具

pkg/                      Go 参考实现（位置不变）
python/                   Python SDK
typescript/               TypeScript SDK
java/                     Java SDK
```

Go 模块保留在仓库根目录。移到 `go/` 会破坏
`go get github.com/axisvela/praxo-core/v2` 以及所有既有 import。新目录都是增量。

抽取流程：

1. 读取 Go 声明。
2. 编写或更新 `spec/wire` 产物。
3. 增加 `spec/parity.md` 行。
4. 增加证明行为的向量。
5. 运行 Go runner，确认向量与当前行为一致。
6. 实现 SDK，使同一向量通过。

`spec/parity.md` 纳入版本库。CI 验证每一行在所有已发布 SDK 中都有实现；缺失行或
静默改名都会使构建失败。

## 语言包

| 语言 | 分发 | 导入根 | 最低运行时 |
| --- | --- | --- | --- |
| Go | `github.com/axisvela/praxo-core/v2` | `pkg/...` | Go 1.25 指令 |
| Python | `praxo-core` | `praxo` | Python 3.11 |
| TypeScript | `@axisvela/praxo-core` | `@axisvela/praxo-core` 及子路径 | Node 20，`ES2022` |
| Java | `io.axisvela:praxo-core` | `io.axisvela.praxo` | Java 21 |

领域映射：

| 领域 | Python | TypeScript | Java |
| --- | --- | --- | --- |
| model | `praxo.model` | `@axisvela/praxo-core/model` | `io.axisvela.praxo.model` |
| tool | `praxo.tool` | `@axisvela/praxo-core/tool` | `io.axisvela.praxo.tool` |
| event | `praxo.event` | `@axisvela/praxo-core/event` | `io.axisvela.praxo.event` |
| memory | `praxo.memory` | `@axisvela/praxo-core/memory` | `io.axisvela.praxo.memory` |
| policy | `praxo.policy` | `@axisvela/praxo-core/policy` | `io.axisvela.praxo.policy` |
| checkpoint | `praxo.checkpoint` | `@axisvela/praxo-core/checkpoint` | `io.axisvela.praxo.checkpoint` |
| agent | `praxo.agent` | `@axisvela/praxo-core/agent` | `io.axisvela.praxo.agent` |

可选适配器使用独立分发包/构件，绝不进入核心包。

## 范围矩阵

| 能力 | Python | TypeScript | Java | 说明 |
| --- | --- | --- | --- | --- |
| Model、tool、event、policy、memory 契约 | P1 | P1 | P1 | 一致性必需 |
| Checkpoint 与会话契约 | P1 | P1 | P1 | 一致性必需 |
| Agent 循环、预算、核心中间件 | P1 | P1 | P1 | 一致性必需 |
| 流式投影 | P1 | P1 | P1 | 使用各语言异步迭代 |
| OpenAI 兼容适配器 | P1 | P1 | P1 | 每个 SDK 的首个适配器 |
| Anthropic/Gemini 适配器 | P2 | P2 | P2 | 按需求 |
| MCP 网关 | P2 | P2 | P2 | 按需求 |
| OTel sink | P2 | P2 | P2 | 按需求 |
| VFS 与本地后端 | P2 | P2 | P2 | 安全敏感 |
| 调度器契约 | P3 | P3 | P3 | 运行时仍归产品所有 |
| 进程插件宿主 | P3 | P3 | P3 | 先做线格式契约 |
| WASM 插件宿主 | P4 | P4 | P4 | 各语言绑定差异大 |

P1 是 SDK `1.0.0` 发布的必要条件。P2 随采用推进。P3/P4 只在有可验证使用方时发布。

## 兼容与版本

- `spec/SPEC_VERSION` 版本化契约，从 `0.1.0` 开始。
- 每个 SDK 独立版本化，并声明支持的 `SPEC_VERSION`。
- 线格式变更是所有 SDK 的破坏性变更，即使只有一个 SDK 发布。
- 行为变更需要更新向量，并以 SDK 次要版本发布。
- 新增可选字段或事件键属于增量变更。
- 删除或重命名线格式字段、事件、stream kind 或插件字段属于破坏性变更，需要
  spec 主版本。
- 任何 SDK 不得发布 Go 参考实现尚不具备的契约能力。

[API 冻结清单](07-api-freeze.md)中的 Go API 冻结仍是 Go 表面的依据。多语言契约
是该表面的投影加文档化线格式行为，不放宽 Go API。

## 安全与许可

- 所有 SDK 保持 MIT。
- 依赖必须在采用前审查并保持宽松许可。
- 任何 SDK 不得导入 AGPL 代码。
- 凭据和租户标识保留在适配器配置中。
- 插件物化、签名信任、SBOM 与滚动更新在每种语言中都归产品所有。
- 路径约束与沙箱行为必须按语言重新验证，不能从 Go 继承。

## 成功标准

- 一棵 `spec/` 树，被四个 CI 任务消费。
- 每个已发布 SDK 的 `spec/parity.md` 零缺口。
- 同一组向量产生相同事件、错误和循环结果。
- 使用方切换语言时无需重写提示词、工具、事件或检查点数据。

## 相关文档

- [架构](01-architecture.md)
- [基础能力](02-primitives.md)
- [多语言路线图](18-multilingual-roadmap.md)
- [兼容性](05-compatibility.md)
- [兼容与弃用策略](16-compatibility-policy.md)
- [事件 schema](event-schema.md)
- [插件编写](10-plugin-authoring.md)
