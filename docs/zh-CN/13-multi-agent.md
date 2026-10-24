# 多 Agent 模式

PRAXO-CORE 的核心是单 Agent 执行循环，并提供异步子 Agent 委派。核心不自带
graph、handoff、supervisor、共享状态或 Agent registry 运行时；下文的可选模块
提供进程内 supervisor 与顺序组合，不提供持久化工作流语义。

## 已内置

- `pkg/agent/delegation.SubagentManager`：launch、check、wait、update、cancel、
  list、prune
- `SubagentIsolated`：子 Agent 仅接收请求上下文
- `SubagentFork`：子 Agent 继承父消息历史
- 终态任务不会被 `Cancel` 覆盖；只有运行中的任务接受 `Update`
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
done, err := manager.Wait(ctx, task.ID)
```

路由器与 `SubagentRunner` 由产品提供；框架负责任务生命周期和可观察状态。

## 可选编排模块

[`adapters/multiagent`](https://github.com/axisvela/praxo-core/tree/main/adapters/multiagent)
在 `SubagentManager` 之上提供一个小的可选层：

- `Supervisor.Run` 并行启动 worker 并按名称聚合输出；`MaxConcurrency` 限制
  同时运行的 worker 数量。
- `Supervisor.Sequential` 将前一个输出作为 `Context["previous"]` 传给下一个
  worker。
- 完成事件通过 `SubagentManager.Wait` 驱动，Supervisor 不再轮询。
- 超时会取消未完成的子上下文并返回 `ErrTimeout`。

它不是图或持久化工作流运行时，也不会改变核心 API。

## 使用 RHEOVELA 做持久化编排

当工作流需要持久化图/子图执行、恢复、租约或图级中断时，应使用 RHEOVELA。
PRAXO-CORE 提供 Agent 会话和流边界；RHEOVELA 拥有图。

[`examples/ecosystem-sdk`](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/rheovela)
中有 `rheovela.Runner` recipe：

```go
runner := rheovela.Runner{
    Client:    rheovela.NewClient("http://127.0.0.1:8080"),
    Workflow:  "agent",
    ProjectID: "proj",
    Actor:     "agent-1",
}

instance, err := runner.Start(ctx, session)
err = runner.Step(ctx, instance.InstanceID, "advance", "review")
audit, err := runner.Audit(ctx, instance.InstanceID)
```

### 边界清单

- PRAXO-CORE 不定义 graph 节点、边、子图或图级中断。
- RHEOVELA 拥有图执行、持久化恢复、租约和路由。
- PRAXO-CORE 只暴露 Agent 节点/会话/流契约。
- 产品拥有任务存储、凭据、授权和审计保留。
- `adapters/multiagent` 只用于进程内 supervisor/顺序委派。
- 不要声称 `SubagentManager` 或 `adapters/multiagent` 具备持久化执行能力。

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
