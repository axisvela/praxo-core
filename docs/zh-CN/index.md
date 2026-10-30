# PRAXO-CORE

**可嵌入产品的 MIT 许可 Agent 框架，提供显式策略控制、检查点与事件追踪。**

无需重复实现 Agent 循环、模型抽象、工具契约和执行边界。可以使用自己的模型
提供商和集成，不要求使用任何 AxisVela 产品。

[快速开始](getting-started/quickstart.md){ .md-button .md-button--primary }
[选择语言](languages/index.md){ .md-button }
[GitHub](https://github.com/axisvela/praxo-core){ .md-button }

## 为什么选择 PRAXO-CORE

- 通过明确的策略钩子与审批边界控制工具执行。
- 使用检查点恢复任务，通过结构化事件观察执行过程。
- 嵌入与提供商无关的模型、工具、记忆和沙箱契约。
- 从 Go 参考实现开始，或选择范围明确的语言实现。
- 框架保持 MIT 许可，可选集成与核心分离。

## 从 Go 开始

```bash
go get github.com/axisvela/praxo-core/v2@v2.5.2
```

通过[快速开始](getting-started/quickstart.md)连接 Ollama 或 OpenAI 兼容端点。
其他语言请查看[语言实现目录](languages/index.md)。源码标签不等于已发布到包管理器。

## 按目标阅读

| 目标 | 入口 |
| --- | --- |
| 评估是否适合自己的产品 | [采用指南](getting-started/adoption.md)、[框架对比](project/comparison.md) |
| 连接模型或外部工具 | [适配器目录](integrations/index.md)、[接入示例](guides/recipes.md) |
| 理解运行时和安全边界 | [架构](reference/architecture.md)、[安全模型](security/index.md) |
| 编写插件或委派任务 | [插件编写](guides/plugins.md)、[多 Agent 模式](guides/multi-agent.md) |
| 升级已有集成 | [兼容性](project/compatibility.md)、[版本历史](releases/index.md) |

## 当前版本

核心 `2.5.2` 是安全与行为修正补丁，覆盖 rooted local VFS、受治理示例、上下文信任、OTel 示例和验证证据。查看[最新发布说明](releases/2.5.2.md)或[版本总览](releases/index.md)。

PRAXO-CORE 是框架，不是托管服务或开箱即用的聊天产品。
[AxisVela 生态集成](integrations/ecosystem.md)是可选项。
