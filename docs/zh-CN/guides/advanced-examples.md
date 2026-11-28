# 高级示例

高级示例从单一模型/工具循环推进到委派、长时操作、工作区、Plugin 和其他应用自有接缝。
它们不是新的 Profile，也不表示生产就绪。

## 应用级委派

父子委派示例展示应用层模式：父 Agent 调用 `delegate` 工具，该工具以不同的工具范围和策略
运行子 Agent，并在父 Agent 完成前验证子效果。示例只使用共享的 Agent、Tool 和 Policy
接缝。

| 语言 | 示例 | 运行 |
| --- | --- | --- |
| Go | [`language/go/examples/multiagent`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/multiagent) | `go test ./...` |
| Python | [`language/python/examples/advanced-delegation`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/advanced-delegation) | `python delegation.py` |
| TypeScript | [`language/typescript/examples/advanced-delegation`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/advanced-delegation) | `npm start` |
| Java | [`language/java/examples/advanced-delegation`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/advanced-delegation) | `mvn -q compile exec:java` |
| C# | [`language/csharp/examples/advanced-delegation`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/advanced-delegation) | `dotnet run --project AdvancedDelegation.csproj` |
| Rust | [`language/rust/examples/advanced-delegation`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/advanced-delegation) | `cargo run` |

在 Core SDK 集合中，治理示例还检查子 scope 收窄、父子策略组合、兄弟共享预算、
子任务数与深度限制、取消后零效果以及最终参数重授权。它们不实现自动父策略继承或
取消传播，这些仍由应用负责。Go 管理器示例另有生命周期范围。源码存在不代表每个包和
工具链均已实测；运行声明必须对应[验证证据](../project/evaluation/verification-evidence.md)
中的记录。

这不是 Go `pkg/agent/delegation` 契约。持久 worker、远程任务队列、重试、取消传播和效果
对账仍由应用负责。

## 长时操作

Go 参考配方
[`language/go/examples/recipes/long-running-go`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/long-running-go)
展示应用自有的提交、状态、取消、恢复、fencing、验证器和持久状态模式。完整范围和限制见
[长时操作配方](long-running-operations.md)。

其他 SDK 的长时操作示例尚未提供。请从 Go 配方开始，并把操作状态、效果验证和对账保留在
应用中。

## 工作区

Go 参考示例
[`language/go/examples/governed-workspace`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/governed-workspace)
展示受治理的只读工作区路径。引导式发布包版本见
[Workspace Agent 教程](workspace-agent-tutorial.md)。

未暴露 Workspace 接缝的 SDK 仍由应用负责 Workspace Provider 和 VFS 后端。不能因为某种
语言有 Agent 循环就推断它支持 Workspace。

## Plugin

Go 参考示例
[`language/go/examples/plugin`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/plugin)
展示 Plugin 生命周期、受保护状态转换、in-flight drain、revoke 和 quarantine。Plugin Host
仍以 Go 为先；其他 Core 应明确记录差距。

## 添加高级示例

一个高级示例可以发布时应满足：

1. 无需 provider 端点即可确定性运行；
2. 检查拒绝或隔离属性，而不只是顺利路径；
3. 说明使用的是 Core 接缝还是应用级模式；
4. 记录包或源码版本以及精确命令；
5. 凭据、持久状态、隔离和效果验证保留在应用中。

不要仅为补齐矩阵而增加语言实现或 Adapter。高级工作需要明确消费者和具体项目需求。

## 当前差距

- 委派示例覆盖 Go、Python、TypeScript、Java、C# 和 Rust。其余已声明语言尚无委派示例。
- 长时操作、Workspace 和 Plugin 示例以 Go 为先，不承诺跨语言可用。
- 运行 `python -m scripts.checks.check_example_coverage --report-advanced` 查看当前逐语言高级覆盖。
  缺失条目是已记录差距，不是通过。

## 相关文档

- [示例目录](../getting-started/examples.md)
- [语言覆盖](../getting-started/language-coverage.md)
- [多 Agent 模式](multi-agent.md)
- [长时操作](long-running-operations.md)
- [Plugin](plugins.md)
- [执行 Profile](../reference/execution-profiles.md)
