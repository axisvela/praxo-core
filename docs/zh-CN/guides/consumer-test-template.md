# 消费者测试模板

将与应用风险档位匹配的检查复制到消费者仓库，不要复制整个 Core 测试矩阵。
可运行的消费者 Starter 和结构化输出示例展示了相同的代码模式。

## 每个应用的最小检查

在集成所在位置保留：

1. 应用能启动并到达模型 Adapter；
2. 允许的工具调用成功执行一次；
3. 拒绝调用不产生工具副作用；
4. 缺少 Policy 或必需依赖时失败关闭；
5. 锁文件中的包版本与目标发布版本一致。

Go 消费者示例：
[`language/go/examples/consumer-go/governed_test.go`](https://github.com/axisvela/praxo-core/blob/main/language/go/examples/consumer-go/governed_test.go)。

## 有副作用应用

当工具可以写入、发送、删除或支付时增加：

- Middleware 或审批修改后，对最终参数重新授权；
- 未知结果先查询再重试；
- 幂等键或操作键绑定到效果；
- 分别记录 Run 完成和效果验证；
- 取消记录为请求、已确认、拒绝或未知；
- 损坏或部分写入的 Checkpoint 状态失败关闭。

参见[长时操作](long-running-operations.md)。

## 高风险或多租户应用

当部署具有特权、多租户或安全相关性时增加：

- 缺少、过期或租户不匹配的 principal 被拒绝；
- Policy 或身份服务故障不允许执行；
- 撤销作用于排队中的工作；
- 租户级 Checkpoint 和事件不能跨租户读取；
- Shell、文件和网络效果在声明边界外被阻止；
- 操作员可以停止和恢复，且不会盲目重复效果。

参见[应用嵌入清单](application-integration-checklist.md)和[身份与策略](identity-policy.md)。

## 测试边界

- fake model 证明集成行为，不证明模型质量。
- Loopback 服务证明 Transport 映射，不证明已部署服务。
- 通过一次拒绝测试只证明该次拒绝无副作用，不证明所有路径安全。
- Checkpoint 不是事务，也不证明外部效果。
- 测试实际部署的包版本和应用提交。

## 保留证据

记录包版本、应用 revision、模型端点类别、Policy 负责人、租户范围、命令、
预期结果、实际结果，以及测试运行在源码模式还是已发布包模式。
