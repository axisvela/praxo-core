# PRAXO-CORE

[English](README.md) | [简体中文](README.zh-CN.md)

[![CI](https://github.com/axisvela/praxo-core/actions/workflows/ci.yml/badge.svg)](https://github.com/axisvela/praxo-core/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-axisvela.github.io-blue)](https://axisvela.github.io/praxo-core/zh-CN/)
[![Go Reference](https://pkg.go.dev/badge/github.com/axisvela/praxo-core/v2.svg)](https://pkg.go.dev/github.com/axisvela/praxo-core/v2)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**可嵌入产品的 MIT 许可 Agent 框架，提供显式策略控制、检查点与事件追踪。**

无需重复实现 Agent 循环、模型抽象、工具契约和执行边界。可以使用自己的模型
提供商与集成，不要求使用 AxisVela 产品。

[中文文档](https://axisvela.github.io/praxo-core/zh-CN/) |
[快速开始](docs/zh-CN/getting-started/quickstart.md) |
[语言实现](docs/zh-CN/languages/index.md) |
[示例](examples)

**PRAXO-CORE 是多语言框架。** Go 是参考实现；Python、TypeScript、Java、Rust、C#、R、
Ruby、PHP、Elixir、Lua 等语言都有独立发布包。它不是 Go 专用框架。

## 选择语言

| 语言 | 包 | 开始 |
| --- | --- | --- |
| Go（参考实现） | `github.com/axisvela/praxo-core/v2` | [Go 独立消费者](docs/zh-CN/getting-started/consumer-go.md) |
| Python | `praxo-core` | [Python 独立消费者](docs/zh-CN/getting-started/consumer-python.md) |
| TypeScript | `@axisvela/praxo-core` | [TypeScript 独立消费者](docs/zh-CN/getting-started/consumer-typescript.md) |
| Java | `com.axisvela:praxo-core` | [Java 独立消费者](docs/zh-CN/getting-started/consumer-java.md) |
| Rust | `praxo-core` | [Rust 实现](docs/zh-CN/languages/rust/index.md) |
| C# | `Praxo.Core` | [C# 实现](docs/zh-CN/languages/csharp/index.md) |
| R | `praxocore` | [R 实现](docs/zh-CN/languages/r/index.md) |
| Ruby | `praxo-core` | [Ruby 独立消费者](docs/zh-CN/getting-started/consumer-ruby.md) |
| PHP | `axisvela/praxo-core` | [PHP 独立消费者](docs/zh-CN/getting-started/consumer-php.md) |
| Elixir | `praxo_core` | [Elixir 独立消费者](docs/zh-CN/getting-started/consumer-elixir.md) |
| Lua | `praxo-core` | [Lua 独立消费者](docs/zh-CN/getting-started/consumer-lua.md) |

完整列表见[语言实现目录](docs/zh-CN/languages/index.md)与
[独立仓库索引](docs/zh-CN/languages/repositories.md)。

## Go 参考实现快速开始

Go 是参考实现；其他运行时请使用上表。

```bash
go get github.com/axisvela/praxo-core/v2@v2.7.0
```

先通过[Go 独立消费者](docs/zh-CN/getting-started/consumer-go.md)在自己的应用安装发布包，
运行确定性的允许/拒绝测试，无需检出源码、API Key 或模型服务。

然后从源码仓库运行 Ollama 端点示例：

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
GOWORK=off go run ./examples/quickstart
```

连接其他 OpenAI 兼容端点时，设置 `PRAXO_BASE_URL`、`PRAXO_API_KEY` 和
`PRAXO_MODEL`。PowerShell 使用 `$env:PRAXO_BASE_URL = "..."` 等写法。
CI 与发布使用 Go 1.26.11。示例展示工具调用、流式文本、事件与策略，前置条件见
[快速开始](docs/zh-CN/getting-started/quickstart.md)。

## 核心价值

- **明确治理边界：** 策略钩子、工具授权、人工审批与决策。
- **可恢复执行：** 检查点与会话契约支持恢复任务。
- **可观察行为：** 结构化事件与可选 OpenTelemetry 集成。
- **提供商无关：** 模型、记忆、工具、检索、沙箱接口可自行适配。
- **MIT 边界：** 可选集成与框架核心分离。

### 实现、证据与消费者责任

**Governed, Embeddable Agent Execution Kernel** 描述嵌入边界，不代表开箱即用的企业安全体系。
Go 参考实现覆盖完整接口；各语言实现分别声明范围与证据。

| 领域 | Core 实现什么 | 测试验证什么 | 消费者必须提供什么 |
| --- | --- | --- | --- |
| Governed | Policy 钩子、工具授权与 HITL 集成 | 配置后的允许、拒绝与审批路径 | 身份认证、策略配置与强制执行；Agent 可以不配置 Policy |
| Sandbox Support | 执行契约与适配器 | 契约行为与选定适配器边界 | 真实隔离运行时和部署加固；接口不等于操作系统隔离 |
| Recoverable | Session/Checkpoint 契约与恢复集成 | 序列化与限定范围的恢复夹具 | 持久存储、效果验证和幂等；Checkpoint 不保证外部事务或 exactly-once |
| Multilingual | 共享规范与独立语言实现 | 各语言声明的向量和行为覆盖 | 按语言限制选型，不假设完整 Go 功能对齐 |
| Multi-Agent | 局部 Subagent 委派 | 声明测试范围内的委派行为 | 按需提供分布式协调与持久编排 |

证据层次见[测试分类](docs/zh-CN/project/test-taxonomy.md)，发布包验证见
[消费者 Starter](docs/zh-CN/getting-started/coding-agents.md)。

一个 Kernel 支持三个[集成层次](docs/zh-CN/reference/execution-profiles.md)：
**Standard Embedding**（现有行为）、**Governed Execution Profile**（验收提案，已有部分证据）、
**Embodied Integration Profile**（设计提案；AKROVELA 产品侧 P1 适配器与确定性切片已存在，E1-E8 试点未运行）。它们不是独立包或运行时开关。
必需治理由可信产品入口和实际效果边界执行，不能靠 Profile 名称产生。

它不是托管 Agent 服务、向量数据库、模型提供商或开箱即用的聊天产品。采用前请阅读
[采用指南](docs/zh-CN/getting-started/adoption.md)、[安全模型](docs/zh-CN/security/index.md)
和[框架对比](docs/zh-CN/project/comparison.md)。

## 选择语言

Go 是参考实现，语言 SDK 共享 [`spec/`](spec/README.md) 中的规范契约，
提供符合各语言习惯的 API，并分别声明支持范围与限制。

| 运行时 | 使用入口 |
| --- | --- |
| Go | [安装与快速开始](docs/languages/go/index.md) |
| Python | [Python SDK](https://axisvela.github.io/praxo-core/zh-CN/languages/python/) |
| TypeScript / JavaScript | [TypeScript SDK](https://axisvela.github.io/praxo-core/zh-CN/languages/typescript/)、[JavaScript 示例](https://axisvela.github.io/praxo-core/zh-CN/languages/javascript/) |
| Java / Kotlin / Scala | [Java SDK](https://axisvela.github.io/praxo-core/zh-CN/languages/java/)、[Kotlin](https://axisvela.github.io/praxo-core/zh-CN/languages/kotlin/)、[Scala](https://axisvela.github.io/praxo-core/zh-CN/languages/scala/) |
| .NET | [C# SDK](https://axisvela.github.io/praxo-core/zh-CN/languages/csharp/)、[Visual Basic 示例](docs/languages/visual-basic/index.md) |
| 其他语言 | [完整语言实现目录](docs/zh-CN/languages/index.md) |

源码发布、包管理器发布、一致性测试和生产验证是不同状态。请按各语言页面安装，
并阅读[支持政策](docs/zh-CN/languages/support.md)，不能从源码标签推断完整功能一致或包仓库可用。

行为覆盖与契约阶段分开跟踪：agent-capable 为 Go、Python、TypeScript、Java、Rust、R、C#；
extended 为 PHP、C、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua；其他已声明实现属于
optional。当前覆盖见[行为实验](docs/zh-CN/languages/behavior-lab.md)。

## 可运行示例

| 目标 | 示例 |
| --- | --- |
| 用发布包连接真实模型 | [真实模型](language/go/examples/live-model) |
| 生成受校验 JSON | [Python](language/python/examples/structured-output)、[TypeScript](language/typescript/examples/structured-output)、[Java](language/java/examples/structured-output)、[C#](language/csharp/examples/structured-output) |
| 构建只读 Workspace Agent | [Workspace agent](examples/workspace-agent) |
| 将 Core 嵌入 HTTP 服务 | [Embedded service](examples/embedded-service) |
| 使用本地 MCP 客户端 | [Python](language/python/examples/mcp)、[TypeScript](language/typescript/examples/mcp)、[C#](language/csharp/examples/mcp) |
| 模型、工具与流式输出 | [Quickstart](examples/quickstart) |
| 审批与拒绝边界 | [Governed workspace](examples/governed-workspace) |
| 检查点恢复 | [Checkpoint](examples/checkpoint) |
| 策略控制命令执行 | [Sandbox](examples/sandbox) |
| 委派任务 | [Multi-agent](examples/multiagent) |
| 使用自己的适配器嵌入 | [Integrator](examples/integrator) |

按任务和语言组织的完整目录：
[文档示例页](docs/zh-CN/getting-started/examples.md)和
[examples/README.md](examples/README.md)。

## 仓库导览

| 位置 | 职责 |
| --- | --- |
| [`pkg/`](pkg) | Go 公开 API |
| [`adapters/`](adapters) | 可选模型、协议、遥测与运行时集成 |
| [`language/`](language/README.md) | 独立语言 SDK 源码、构建、测试与 API 参考 |
| [`bindings/`](bindings/README.md) | Shell 与 PowerShell 运行时桥接 |
| [`spec/`](spec) | 规范契约、共享向量与 parity 清单 |
| [`examples/`](examples) | 可运行示例 |
| [`docs/`](docs) | 按用户任务分类的公开文档 |

Go 导入路径保持不变，语言源码已归入 `language/`、`bindings/` 和 `examples/`，
使用方请查看[源码迁移说明](docs/zh-CN/project/repository-layout.md)。

## 框架与生态

GitHub Latest Release 仅代表 Go 参考 Core（`vX.Y.Z`）。语言与适配器独立版本化，
通过[语言发布索引](docs/zh-CN/languages/registry-status.md)发现，不占用 Latest 入口。

PRAXO-CORE 是独立的 MIT 框架。

可使用自己的适配器，或接入[可选 AxisVela 生态](docs/zh-CN/integrations/ecosystem.md)。
具体模块范围和限制见[适配器目录](docs/zh-CN/integrations/index.md)。

## 版本与贡献

核心 `2.7.0` 是次版本发布，增加长运行操作服务、验证器、租约、指标与凭据轮换配方，已发布包升级检查，以及更多集成与采用证据。适配器和 Core 实现独立版本化。

- [最新发布说明](docs/zh-CN/releases/2.7.0.md)
- [版本历史](docs/zh-CN/releases/index.md)
- [兼容政策](docs/zh-CN/project/compatibility-policy.md)
- [v2 迁移](docs/zh-CN/project/migration-v2.md)
- [公开路线图](ROADMAP.md)
- [贡献指南](CONTRIBUTING.md)
- [安全问题报告](SECURITY.md)

## 许可证

MIT。参见 [LICENSE](LICENSE) 与[来源说明](docs/zh-CN/project/provenance.md)。
