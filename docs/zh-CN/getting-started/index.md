# 阅读导览

1. 阅读[概览](overview.md)，理解框架的职责与边界。
2. 按语言选择[独立消费者](consumer-go.md)。
3. 运行[快速开始](quickstart.md)。
4. 嵌入产品之前检查[采用指南](adoption.md)。
5. 如果仍在评估是否适合，请阅读[何时不应选择 PRAXO-CORE](when-not-to-use.md)。

## 按任务选择

| 需求 | 起点 | 重要边界 |
| --- | --- | --- |
| 让编程 Agent 接入 Core | [面向编程 Agent](coding-agents.md)、[包映射](agent-integration.json) | 精简契约与版本校验的包映射；不是隐蔽安装渠道或自动 Skill |
| 为 Go、Python、TypeScript 或 Java 应用加入模型/工具循环 | [Go](consumer-go.md)、[Python](consumer-python.md)、[TypeScript](consumer-typescript.md) 或 [Java](consumer-java.md) 独立消费者 | 使用发布包、确定性模型、显式工具范围与拒绝测试；身份、持久化和隔离由应用负责 |
| 授权工具并证明拒绝无副作用 | 同上消费者 Starter | Policy Hook 是执行控制点，不是身份服务或进程沙箱 |
| 绑定已验证身份与策略 | [身份与策略配方](../guides/identity-policy.md) | 应用负责认证并提供可信 principal；模型提供的角色被忽略 |
| 增加远端长时操作 | [长时操作配方](../guides/long-running-operations.md) | Run 状态、取消请求/确认与远端效果证据保持分离 |
| 人工审批、Checkpoint 或恢复 | [接入示例](../guides/recipes.md)、[采用指南](adoption.md)、[受治理执行设计](../reference/governed-execution.md) | 持久审批、lease 与效果对账属于集成职责；设计仍是提案，不是 Profile 保证 |
| 持久图工作流、exactly-once 或托管沙箱 | 先读[何时不应选择 PRAXO-CORE](when-not-to-use.md) | Core 提供接口，不提供这些产品或保证 |

## 按任务继续

| 任务 | 文档 |
| --- | --- |
| 接入应用 | [集成](../guides/integration.md)、[接入示例](../guides/recipes.md) |
| 连接提供商或协议 | [适配器目录](../integrations/index.md) |
| 编写插件 | [插件指南](../guides/plugins.md) |
| 委派任务 | [多 Agent 模式](../guides/multi-agent.md) |
| 理解契约 | [架构](../reference/architecture.md)、[基础能力](../reference/primitives.md)、[事件](../reference/events.md) |
| 评估安全性 | [安全模型](../security/index.md) |
| 升级 | [兼容性](../project/compatibility.md)、[版本总览](../releases/index.md) |
| 贡献 Core | [Core 设计](../contributing/core-design.md)、[语言支持规范](../contributing/language-policy.md) |
