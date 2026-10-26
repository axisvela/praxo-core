# 事件与 OpenTelemetry Schema

本页记录 Agent 循环发出的事件名称、负载，以及 `adapters/otel` 的映射。它是
兼容性说明，不是投递保证。

## 事件信封

`event.Event` 是所有 Sink 共享的线格式：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `type` | string | 稳定的事件名 |
| `sessionId` | string | 会话标识 |
| `runId` | string | 运行标识；Agent 循环之外可能为空 |
| `data` | object | 事件负载；可能不存在 |
| `at` | RFC 3339 时间戳 | 发出时间；发送方留空时由框架设为 UTC |

事件是进程内通知。`event.Sink` 不承诺重试、投递或持久化。`event.MultiSink`
遇到第一个 Sink 错误即停止，因此后续 Sink 可能收不到该事件。

## Agent 事件类型

| 类型 | data 键 | 触发时机 |
| --- | --- | --- |
| `run.started` | 无 | 运行进入受治理循环 |
| `run.completed` | 无 | 运行成功返回 |
| `run.failed` | `error`（string） | 运行返回错误，包括策略或审批拒绝 |
| `tool.call` | `name`（string）、`arguments`（object） | 工具调用即将执行 |
| `tool.interrupt` | `name`（string）、`arguments`（object） | 工具调用等待审批决定 |

`arguments` 可能包含租户数据、提示词、文件路径或调用方提供的凭据。持久化或
导出前必须脱敏。

## Stream 投影

`agent.Options.OnStream` 接收 `agent.StreamPart`。它是独立的类型化投影，不是
`event.Sink` 事件：

- `values`、`updates`、`messages`、`tasks`、`debug`、`checkpoint`
- `tasks` 当前携带工具任务状态转换的 `status`、`name` 和 `arguments`

Stream 投影按加法演进。使用方必须忽略未知 kind 和未知 data 字段。

## 兼容规则

- v2 模块线内事件类型字符串保持稳定。重命名或删除需要新的主版本。
- 次要版本可以新增事件类型和 `data` 键。
- 使用方必须忽略未知事件类型和未知 data 键。
- `data` 值必须保持 JSON 可序列化。允许嵌套 map 和 slice。
- 事件顺序是单个 Sink 的发送顺序。并发工具调用可能按完成顺序发出事件。
- `event.MultiSink` 是 fail-fast，不是 best-effort 扇出。
- 事件负载不是持久审计记录。需要持久化的产品应在确认运行前写入存储。

## OpenTelemetry 映射

`adapters/otel` 将一个事件映射为一个 span：

| Span 字段 | 值 |
| --- | --- |
| 名称 | `praxo.<event type>` |
| `praxo.event.type` | 事件类型 |
| `praxo.session.id` | 会话 ID（存在时） |
| `praxo.run.id` | 运行 ID（存在时） |
| `praxo.event.at` | UTC 发出时间（存在时） |
| `praxo.event.data.<key>` | 选中的数据值，仅通过 `AllowedDataKeys` |

`Event.Data` 默认不导出。选中某个键会导出其 `fmt.Sprint` 值，且不会脱敏。
没有单独脱敏策略时，不要选择 arguments、结果、凭据或其他敏感字段。

事件 span 继承传给 `Emit` 的 context 中的父 span。每个 span 表示一个事件，
不是完整运行的持续时间。

## 验证

- `conformance.CheckEventSink` 验证 Sink 能接受格式正确的事件。
- OTel 适配器测试覆盖 span 命名、属性、数据排除、允许列表和父 trace 继承。
- 这些检查不证明投递、保留或后端访问控制。
