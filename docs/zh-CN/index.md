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
go get github.com/axisvela/praxo-core/v2@v2.10.0
```

通过[快速开始](getting-started/quickstart.md)连接 Ollama 或 OpenAI 兼容端点。
其他语言请查看[语言实现目录](languages/index.md)。源码标签不等于已发布到包管理器。

## 选择语言

| 语言 | 今天能构建什么 | 起点 |
| --- | --- | --- |
| Go（参考） | 发布模块、治理 allow/deny、真实模型链路、参考示例 | [Go 独立消费者](getting-started/consumer-go.md) |
| Python | 发布包、治理验收、HITL、Streaming、MCP | [Python 独立消费者](getting-started/consumer-python.md) |
| TypeScript | 发布包、治理验收、HITL、Streaming、MCP | [TypeScript 独立消费者](getting-started/consumer-typescript.md) |
| Java | 发布包、治理验收、HITL、Streaming、MCP | [Java 独立消费者](getting-started/consumer-java.md) |
| Rust | 发布 crate、HITL、Streaming、MCP、OIDC 服务示例 | [Rust 实现](languages/rust/index.md) |
| C# | 发布 NuGet 包、HITL、Streaming、MCP、OIDC 服务 | [C# 实现](languages/csharp/index.md) |
| R | r-universe 源码发布、HITL、Streaming、分析工作流 | [R 实现](languages/r/index.md) |
| Ruby | 发布 gem、allow/deny Starter、HITL、Streaming、OIDC 服务 | [Ruby 独立消费者](getting-started/consumer-ruby.md) |
| PHP | 发布包、allow/deny Starter、HITL、Streaming、OIDC 服务 | [PHP 独立消费者](getting-started/consumer-php.md) |
| Elixir | 发布包、allow/deny Starter、HITL、Streaming、进程插件 | [Elixir 独立消费者](getting-started/consumer-elixir.md) |
| Lua | 发布 rock、allow/deny Starter、HITL、Streaming | [Lua 独立消费者](getting-started/consumer-lua.md) |

这些描述表示可构建路径，不代表完整功能对齐或生产就绪。Registry 版本可能落后源码
标签；安装前查看[注册表发布状态](languages/registry-status.md)。

## 按目标阅读

| 目标 | 入口 |
| --- | --- |
| 选择任务和证明该任务的路径层级 | [阅读导览中的任务到路径表](getting-started/index.md) |
| 评估是否适合自己的产品 | [采用指南](getting-started/adoption.md)、[框架对比](project/comparison.md) |
| 连接模型或外部工具 | [适配器目录](integrations/index.md)、[接入示例](guides/recipes.md) |
| 理解运行时和安全边界 | [架构](reference/architecture.md)、[安全模型](security/index.md) |
| 编写插件或委派任务 | [插件编写](guides/plugins.md)、[多 Agent 模式](guides/multi-agent.md) |
| 升级已有集成 | [兼容性](project/compatibility.md)、[版本历史](releases/index.md) |

## 当前版本

核心 `2.10.0` 在已声明语言的 Core Adapter 中增加 OpenAI-compatible、Anthropic 和
Gemini SSE Streaming，增加 Go 参考 WASM 插件宿主，以及各语言 Core 的进程插件宿主。
它延续 `2.9.0` 的 Go 记忆召回角色修复：召回内容作为不可信 user 数据注入，而不再进入
system 消息。查看[最新发布说明](releases/2.10.0.md)或[版本总览](releases/index.md)。

PRAXO-CORE 是框架，不是托管服务或开箱即用的聊天产品。
[AxisVela 生态集成](integrations/ecosystem.md)是可选项。

## 交流与社区

- X：<https://x.com/axisvela>
- 微博：<https://weibo.com/u/1936025761>
