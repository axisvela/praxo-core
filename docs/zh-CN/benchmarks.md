# 基准测试

PRAXO-CORE 包含受治理 Agent 循环的回归基准测试。它们使用脚本化模型测量框架
开销，不是跨框架性能对比。

## 运行

```bash
GOWORK=off go test ./benchmarks -bench '.*' -benchmem
```

## 场景

| 基准 | 测量内容 |
| --- | --- |
| `BenchmarkAgentSimple` | 一次模型调用并返回最终答案 |
| `BenchmarkAgentToolCall` | 一次工具调用后返回最终答案 |
| `BenchmarkAgentParallelTools` | 单步内八次工具调用 |
| `BenchmarkAgentContextBudget` | 40 条消息会话加上下文压缩 |

## 方法

- 模型是脚本化的，因此基准不包含网络和提供商延迟。
- 工具执行在进程内完成，且行为确定。
- 每个基准在每次迭代前重置模型状态。
- 结果包含事件、策略和中间件管线开销。

源码和示例结果位于
[`benchmarks/`](https://github.com/axisvela/praxo-core/tree/main/benchmarks)。
请用这些数字在自己的硬件上检测回归，而不是作为项目之间的对比。
