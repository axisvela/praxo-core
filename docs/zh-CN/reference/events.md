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

## Go 结束顺序

尚未发布的 Go 源码先执行 `AfterRun` middleware，包括结构化输出校验和修复，
然后依次执行 `OnRunComplete`、`checkpoint` 投影、记忆写入和 `run.completed`。
校验或修复失败时不发送最终 checkpoint、不保存答案，也不发送完成通知。
原始模型消息和文本增量仍是临时输出，可能已在最终校验之前发送。

`OnRunComplete` 接收已验证结果的副本。它可以返回错误来阻止完成，但修改副本
不会改写最终结果、运行 ID、checkpoint 投影或记忆记录。需要主动转换输出时，
应使用结束提交前的 `AfterRun` middleware。

完成 hook、checkpoint 回调或记忆写入出错会阻止完成通知，并进入运行失败路径。
若 `run.completed` 的 Sink 自身返回错误，`Run` 会返回该错误并调用 `OnRunError`，
但不再尝试 `run.failed`，因为 fail-fast Sink 可能已向部分消费者发送完成通知。
因此收到完成通知不保证 `Run` 返回 nil；即使同时返回结果，也必须检查错误。

这些回调和写入不是原子事务。checkpoint 投影之后记忆写入仍可能失败；事件投递
失败也不会回滚已写入的记忆。checkpoint stream part 是最终结果投影，不代表
持久 checkpoint 已落盘或 exactly-once 执行。需要事务持久化时由消费者实现。
历史 source tag 保留原来的回调顺序，其他 SDK 的生命周期需要分别验证。

已进入的 middleware 即使在后续 `BeforeRun` 失败时也会执行 `AfterRun`，范围仅限
已进入的前缀，包括返回错误的回调；启动拒绝仍不发送运行事件。`AfterRun` 返回
错误不再阻断后续清理，后续回调接收原始执行错误或第一个结束错误，第一个错误
保持优先。普通回调 panic 仍向外传播，不保证在 `AfterRun` panic 后继续清理。
内置调用限制和工具选择通过内部运行 ID 清理状态，不再依赖非空 `Result`。

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
