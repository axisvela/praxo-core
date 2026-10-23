# 多 Agent 模式

PRAXO-CORE 的核心是单 Agent 执行循环，并提供异步子 Agent 委派。它不自带
graph、handoff、supervisor、共享状态或 Agent registry 运行时。

## 已内置

- `pkg/agent/delegation.SubagentManager`：launch、check、update、cancel、list
- `SubagentIsolated`：子 Agent 仅接收请求上下文
- `SubagentFork`：子 Agent 继承父消息历史
- `SubagentRunner`：由产品实现的子运行接口
- `flow.Chain` 和 `flow.Parallel`：通用 Runnable 组合
- 单 Agent 步骤内的并行工具调用

## 未内置

- graph 与子图执行
- supervisor 与 handoff 编排
- 共享状态或黑板
- Agent registry 与动态路由
- 持久化工作流恢复与图级中断

持久化图执行应使用 RHEOVELA 或产品运行时。核心只保留 Agent 节点/会话/流
边界，不增长竞争的图引擎。

## 示例

[`examples/multiagent`](https://github.com/axisvela/praxo-core/tree/main/examples/multiagent)
异步运行两个子 Agent、聚合结果并取消慢任务。

```go
manager := delegation.NewSubagentManager(router{
    "researcher": agentRunner{agent: researcher},
    "writer":     agentRunner{agent: writer},
})

task, err := manager.Launch(ctx, delegation.SubagentRequest{
    ParentSessionID: "session-1",
    AgentID:         "researcher",
    Prompt:          "find the status",
    Mode:            delegation.SubagentIsolated,
})
```

路由器与 `SubagentRunner` 由产品提供；框架负责任务生命周期和可观察状态。

## 选择模式

| 需求 | 模式 |
| --- | --- |
| 少量异步子任务 | `SubagentManager` |
| 子 Agent 继承父历史 | `SubagentFork` |
| 子 Agent 隔离上下文 | `SubagentIsolated` |
| 通用顺序/并行函数 | `flow` |
| 持久化图、恢复、中断 | RHEOVELA |

## 边界

- 子 Agent 是子运行，不是多 Agent 图运行时。
- 示例是确定性演示，不代表生产验证。
- PII、凭据、策略和事件 Sink 仍由每个子运行的产品侧负责。
- 调用方必须处理取消与失败；管理器只记录状态并取消子上下文。
