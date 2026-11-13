# 阅读导览

1. 通过[概览](overview.md)和[何时不应选择 PRAXO-CORE](when-not-to-use.md)判断是否适合。
2. 运行[快速开始](quickstart.md)，连接真实模型端点。
3. 按语言选择使用发布包的[独立消费者](consumer-go.md)。
4. 使用[采用指南](adoption.md)将首次运行扩展为应用集成。
5. 按[公开路线图](../project/roadmap.md)继续原型、嵌入、加固和高级路径。

## 按任务选择

| 需求 | 起点 | 重要边界 |
| --- | --- | --- |
| 尽快获得有用结果 | [快速开始](quickstart.md)、[真实模型 Golden Path](live-model-golden-path.md) | 连接 OpenAI-compatible 端点；先使用低风险工具，凭据保留在应用中 |
| 让编程 Agent 接入 Core | [面向编程 Agent](coding-agents.md)、[包映射](agent-integration.json) | 精简契约与版本校验的包映射；不是隐蔽安装渠道或自动 Skill |
| 为 Go、Python、TypeScript 或 Java 应用加入模型/工具循环 | [Go](consumer-go.md)、[Python](consumer-python.md)、[TypeScript](consumer-typescript.md) 或 [Java](consumer-java.md) 独立消费者 | 使用发布包、确定性模型、显式工具范围与拒绝测试；身份、持久化和隔离由应用负责 |
| 为 Ruby、PHP、Elixir 或 Lua 应用加入 allow/deny 模型/工具循环 | [Ruby](consumer-ruby.md)、[PHP](consumer-php.md)、[Elixir](consumer-elixir.md) 或 [Lua](consumer-lua.md) 独立消费者 | 扩展语言 Starter 使用发布包并验证确定性 allow/deny；治理负向矩阵仍只覆盖四个试点语言 |
| 使用其他受支持语言 | [语言实现](../languages/index.md)、[支持与分发](../languages/support.md) | 各语言独立版本化；应查看对应安装方式与功能覆盖，不能假设 Go 示例可原样适用 |
| 授权工具并证明拒绝无副作用 | 同上消费者 Starter | Policy Hook 是执行控制点，不是身份服务或进程沙箱 |
| 绑定已验证身份与策略 | [身份与策略配方](../guides/identity-policy.md) | 应用负责认证并提供可信 principal；模型提供的角色被忽略 |
| 增加远端长时操作 | [长时操作配方](../guides/long-running-operations.md) | Run 状态、取消请求/确认与远端效果证据保持分离 |
| 人工审批、Checkpoint 或恢复 | [接入示例](../guides/recipes.md)、[采用指南](adoption.md)、[受治理执行设计](../reference/governed-execution.md) | 持久审批、lease 与效果对账属于集成职责；设计仍是提案，不是 Profile 保证 |
| 持久图工作流、exactly-once 或托管沙箱 | 先读[何时不应选择 PRAXO-CORE](when-not-to-use.md) | Core 提供接口，不提供这些产品或保证 |

## 按任务继续

| 任务 | 文档 |
| --- | --- |
| 浏览可运行示例 | [示例目录](examples.md) |
| 接入应用 | [集成](../guides/integration.md)、[接入示例](../guides/recipes.md) |
| 连接提供商或协议 | [适配器目录](../integrations/index.md) |
| 编写插件 | [插件指南](../guides/plugins.md) |
| 委派任务 | [多 Agent 模式](../guides/multi-agent.md) |
| 理解契约 | [架构](../reference/architecture.md)、[基础能力](../reference/primitives.md)、[事件](../reference/events.md) |
| 评估安全性 | [安全模型](../security/index.md) |
| 升级 | [兼容性](../project/compatibility.md)、[版本总览](../releases/index.md) |
| 贡献 Core | [Core 设计](../contributing/core-design.md)、[语言支持规范](../contributing/language-policy.md) |
