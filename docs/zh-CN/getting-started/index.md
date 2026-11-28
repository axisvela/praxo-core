# 阅读导览

1. 通过[概览](overview.md)和[何时不应选择 PRAXO-CORE](when-not-to-use.md)判断是否适合。
2. 运行[快速开始](quickstart.md)，连接真实模型端点。
3. 按语言选择使用发布包的[独立消费者](consumer-go.md)。
4. 使用[采用指南](adoption.md)将首次运行扩展为应用集成。
5. 按[公开路线图](../project/planning/roadmap.md)继续原型、嵌入、加固和高级路径。

## 任务到路径表

这是文档中唯一的“任务到路径”表；首页和概览都链接到此处，不再分别维护。每一行回答
不同问题：能否运行、包是否可用、集成是否可安全运行、或高级边界是否真正被使用。

| 任务 | 路径层级 | 起点 | 这条路径证明什么 |
| --- | --- | --- | --- |
| 快速获得模型或工具结果 | 体验 | [快速开始](quickstart.md)、[真实模型 Golden Path](live-model-golden-path.md) | 应用能启动并到达 OpenAI-compatible 端点；不证明包可用或生产就绪 |
| 安装发布包并证明 allow/deny | 验证 | [独立消费者](consumer-go.md)：Go、Python、TypeScript、Java、Ruby、PHP、Elixir 或 Lua | 对发布包完成一次允许调用和一次零效果拒绝 |
| 为现有应用加入模型/工具循环 | 嵌入 | [采用指南](adoption.md)、[应用嵌入清单](../guides/application-integration-checklist.md) | Core 被嵌入，配置、身份、持久化和退出由应用负责 |
| 加入已验证身份、审批、Checkpoint 或恢复 | 加固 | [身份与策略](../guides/identity-policy.md)、[Checkpoint 与续跑](../guides/checkpoint-continuation.md)、[长时操作](../guides/long-running-operations.md) | 具体集成失败关闭，并可升级、取消和恢复 |
| 加入 Plugin、委派、长时操作、Workspace 或具身接口 | 扩展 | [高级示例](../guides/advanced-examples.md)、[插件编写](../guides/plugins.md)、[多 Agent 模式](../guides/multi-agent.md) | 高级边界被使用；不表示 Core 强制继承或生产就绪 |
| 按任务浏览可运行示例 | 原型 | [示例目录](examples.md)、[语言覆盖矩阵](language-coverage.md) | 源码入口和深度标签；执行深度因主题和语言而异 |
| 让编程 Agent 接入 Core | 验证 | [面向编程 Agent](coding-agents.md)、[包映射](agent-integration.json) | 版本校验的包映射与契约；不是隐蔽安装渠道或自动 Skill |
| 使用其他受支持语言 | 原型 | [语言实现](../languages/index.md)、[支持与分发](../languages/support.md) | 该语言今天能构建什么；各实现独立版本化 |
| 持久图工作流、exactly-once 或托管沙箱 | 判断 | 先读[何时不应选择 PRAXO-CORE](when-not-to-use.md) | Core 提供接口，不提供这些产品或保证 |

大多数开发者应先完成一层，再进入下一层。各层共享契约，但回答不同问题：
“能否运行？”、“包是否可用？”、“这个具体集成是否可安全运行？”以及“高级边界是否
真正被使用？”。

语言入口描述的是今天能构建什么，而不只是契约层级。构建导向的语言分组见
[语言实现](../languages/index.md)；安装前先查看
[Registry 发布状态](../languages/registry-status.md)。

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
| 升级 | [兼容性](../project/status/version-compatibility.md)、[版本总览](../releases/index.md) |
| 贡献 Core | [Core 设计](../contributing/core-design.md)、[语言支持规范](../contributing/language-policy.md) |
