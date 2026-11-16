# Checkpoint 与续跑路径

PRAXO-CORE 提供 Checkpoint 和 Session 契约，不提供 durable execution、
exactly-once 效果或崩溃步骤恢复。本指南帮助选择最小正确层级，避免把每个 Checkpoint
都当成事务。

## 三个层级

| 层级 | 存储内容 | 支持 | 不支持 |
| --- | --- | --- | --- |
| 消息历史续跑 | Session messages 和应用元数据 | 用已有历史开始新的 Run | 恢复精确步骤或正在执行的工具调用 |
| Allowlist Checkpoint Store | 通过 Core allowlist 序列化的负载 | 重新打开并继续已完成 Run 的状态 | 并发数据库语义、审批或 exactly-once |
| 长时操作状态 | 应用自有操作记录、lease、验证器收据、效果状态 | 提交/状态/取消/恢复和效果验证 | Core 工作流引擎、可信时钟或外部 exactly-once |

只有应用确实需要时才升到下一层。多数集成从消息历史续跑开始。

## 层级 1：消息历史续跑

使用 session-checkpoint 示例：

- Go：[`examples/session-checkpoint`](https://github.com/axisvela/praxo-core/tree/main/examples/session-checkpoint)
- Python、TypeScript、Java、C#、Rust、R、Ruby、PHP、Elixir、Lua 等已声明语言：
  `language/<language>/examples/session-checkpoint`

应用保存 Session messages，并用它们开始新的 Run。这适用于聊天或多轮任务，不是
崩溃 Run 恢复、待处理审批恢复，或可能已产生效果的工具调用恢复。

## 层级 2：Allowlist Checkpoint Store

使用 checkpoint 配方或语言示例：

- Go 配方：[`examples/recipes/checkpoint-store-go`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/checkpoint-store-go)
- 语言示例：`language/<language>/examples/checkpoint`

示例只存储已注册的负载类型，并拒绝未注册类型。教学文件存储使用 temp-file + sync +
rename，并容忍部分临时文件。它不是并发数据库、事务或效果账本。按租户和 Session
划定记录范围，并验证部署所需的并发和故障行为。

## 层级 3：长时操作状态

当应用需要提交、状态、取消、恢复、独立验证器、lease/fencing 或效果对账时，使用 Go
参考配方：

- [`examples/recipes/long-running-go`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/long-running-go)
- [长时操作配方](long-running-operations.md)

操作状态、lease、验证器和外部效果保留在应用中。Run 完成不是外部效果已发生的证明；
取消在应用确认效果边界前只是请求。

## 如何选择

| 问题 | 层级 |
| --- | --- |
| 只需要下一轮看到历史消息？ | 消息历史续跑 |
| 需要重新打开已完成 Run 的序列化状态？ | Allowlist Checkpoint Store |
| 需要恢复崩溃操作、确认取消或对账外部效果？ | 长时操作状态 |

不要用 Checkpoint 做锁、事务、审批存储或 exactly-once 机制；不要用消息历史续跑宣称
durable execution。

## 证据记录

记录包版本、应用 revision、Store 实现、序列化 allowlist、租户/Session 范围、命令、
预期结果、实际结果，以及测试使用 fake model 还是真实端点。包含失败/重启用例，而不
只是顺利路径。
