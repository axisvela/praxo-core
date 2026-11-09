# 长时操作

本配方展示应用如何通过 Core Tool 暴露远端长时操作，同时不混淆 Agent Run 与远端操作。

Core 负责本地 Run、工具调用、Policy 与 Checkpoint 投影。远端执行系统负责 operation ID、
accepted/running 状态、取消确认与最终效果证据。两者通过稳定引用关联，不共享同一状态机。

## 必须区分的状态

| 概念 | 含义 |
| --- | --- |
| Run 取消 | 本地 Agent 循环停止；远端操作不一定停止 |
| 取消请求 | 已向执行权威发送请求；取消尚未确认 |
| 取消确认 | 执行权威报告操作已停止 |
| Accepted | 执行权威接受了操作 |
| Completed | 执行权威报告操作结束 |
| Effect Verified | 环境或业务证据确认预期效果 |

不要把这些合并成一个布尔值。Run 报错不证明远端操作失败，完成事件也不证明业务效果已提交。

## 模式

1. 使用稳定的业务幂等键。新的 Run ID 或模型 tool-call ID 不一定适用。
2. 通过 Tool 提交，并持久化返回的 operation reference。
3. 响应丢失或重启时，先按幂等键/operation ID 查询执行权威，再决定是否重新提交。
4. 单独发送取消请求，并记录执行权威的确认结果。
5. 最终效果证据保留在执行系统或效果账本。
6. 不得从 Checkpoint 或进程内去重表声明 exactly-once。

## 受测示例

可运行示例是独立的 L4 配方模块
[`examples/recipes/long-running-go`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/long-running-go)。
在该目录运行：

```sh
GOWORK=off go test -mod=readonly -run LongRunning -v ./...
```

| 检查 | 预期结果 |
| --- | --- |
| 相同幂等键重复提交 | 同一 operation ID；一次效果 |
| 响应丢失后恢复 | 用相同键查询/提交得到现有操作；不重复 |
| 取消请求 | 状态为 `cancel_requested`，不是 `canceled` |
| 取消确认 | 执行权威仅一次将操作转为 `canceled` |
| Run 取消 | 本地 Run 停止；远端仍为 `accepted`；不误报远端已取消 |
| 文件持久化重启 | operation、幂等键、取消请求与确认在新服务实例中保留 |
| 效果验证 | `completed` 不等于 `effect_verified`；验证需要证据并持久化 |
| 效果收据 | 证据必须携带 verifier 签发的收据；伪造收据被拒绝，状态保持 `completed` |
| HTTP 响应丢失 | 提交已成功但响应丢失；同幂等键重试返回现有操作 |
| HTTP 重启 | 新 loopback 服务加载文件并回答状态/恢复查询 |
| 跨进程重启 | 独立测试进程提供 HTTP；杀掉后用同一文件重启，主进程恢复现有操作 |
| 残留临时文件 | 忽略残留 `.tmp`；最后提交状态与幂等键保持完整 |
| Fencing token | 持有旧 epoch 的 worker 不能完成；新 owner 递增 epoch 并只完成一次 |
| 持久化 fencing | owner、epoch 与完成状态跨重启保留；旧 epoch 仍被拒绝 |
| 独立 verifier 进程 | 执行服务调用独立 verifier 进程且不持有签名密钥；伪造收据被拒绝 |
| Bearer/TLS 边界 | 缺少或错误 token 在产生效果前被拒绝；使用测试 TLS 证书 |
| rename 前故障 | 模拟 rename 边界前崩溃，保留最后提交状态；临时文件被忽略 |
| rename 后故障 | 模拟 rename 边界后崩溃，保留新提交状态 |
| 有效但未提交的临时文件 | 有效的未提交临时文件不会覆盖已提交文件 |
| 已提交文件损坏 | 启动失败关闭，而不是静默从空状态启动 |

Fixture 可持久化到 JSON 文件，并通过 loopback HTTP 暴露，从而在真实传输边界上测试响应
丢失与重启。它仍只展示契约形状，不是持久 worker、lease/fencing 实现或生产效果账本。

## 限制

- 文件存储先写临时文件、同步，再 rename 覆盖主文件。确定性测试会注入 rename 边界前后的
  故障，验证有效的未提交临时文件不能覆盖已提交状态，并要求损坏的已提交状态失败关闭。
  这不是完整崩溃一致性证明：没有同步目录，未演练 OS 级断电和已提交文件损坏恢复，
  多进程并发写入仍不支持。
- HTTP 服务是 loopback 测试 fixture。Bearer token 是静态值，TLS 是测试证书；没有身份
  提供商、token 轮换、租户绑定、限流或生产部署保证。
- 重启包含杀掉子进程并用同一文件重启。故障注入覆盖 rename 边界；OS 级断电和已提交文件
  损坏恢复仍未演练。
- 进程内或单文件去重不是生产 exactly-once 机制。真实服务必须持久化幂等键与结果，并
  定义并发与留存语义。
- 状态查询必须访问权威执行系统，不能只查缓存的 Checkpoint。
- 取消请求不是取消确认；执行权威必须报告最终状态。
- Verifier 是独立 loopback 进程 fixture，但使用静态密钥与 token。真实部署需要密钥管理、
  轮换、撤销与独立运营的验证权威。
- Fencing fixture 可持久化到 JSON 文件，但没有过期、撤销、时钟保证、协调服务或并发写锁。
- 效果验证、生产 lease/fencing、对账与留存属于执行系统或持久工作流产品。
- 本配方不提供 exactly-once。

参见[受治理执行设计](../reference/governed-execution.md)、[安全模型](../security/index.md)
与[何时不应选择 Core](../getting-started/when-not-to-use.md)。
