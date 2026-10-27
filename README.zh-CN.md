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

## 从 Go 开始

```bash
go get github.com/axisvela/praxo-core/v2@v2.5.0
```

从源码仓库运行 Ollama 示例：

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
GOWORK=off go run ./examples/quickstart
```

连接其他 OpenAI 兼容端点时，设置 `PRAXO_BASE_URL`、`PRAXO_API_KEY` 和
`PRAXO_MODEL`。PowerShell 使用 `$env:PRAXO_BASE_URL = "..."` 等写法。
CI 与发布使用 Go 1.26.10。示例展示工具调用、流式文本、事件与策略，前置条件见
[快速开始](docs/zh-CN/getting-started/quickstart.md)。

## 核心价值

- **明确治理边界：** 策略钩子、工具授权、人工审批与决策。
- **可恢复执行：** 检查点与会话契约支持恢复任务。
- **可观察行为：** 结构化事件与可选 OpenTelemetry 集成。
- **提供商无关：** 模型、记忆、工具、检索、沙箱接口可自行适配。
- **MIT 边界：** 可选集成与框架核心分离。

它不是托管 Agent 服务、向量数据库、模型提供商或开箱即用的聊天产品。采用前请阅读
[采用指南](docs/zh-CN/getting-started/adoption.md)、[安全模型](docs/zh-CN/security/index.md)
和[框架对比](docs/zh-CN/project/comparison.md)。

## 选择语言

Go 是参考实现，语言 SDK 共享 [`spec/`](spec/README.md) 中的规范契约，
提供符合各语言习惯的 API，并分别声明支持范围与限制。

| 运行时 | 使用入口 |
| --- | --- |
| Go | [安装与快速开始](docs/languages/go.md) |
| Python | [Python SDK](https://axisvela.github.io/praxo-core/zh-CN/languages/python/) |
| TypeScript / JavaScript | [TypeScript SDK](https://axisvela.github.io/praxo-core/zh-CN/languages/typescript/)、[JavaScript 示例](https://axisvela.github.io/praxo-core/zh-CN/languages/javascript/) |
| Java / Kotlin / Scala | [Java SDK](https://axisvela.github.io/praxo-core/zh-CN/languages/java/)、[Kotlin](https://axisvela.github.io/praxo-core/zh-CN/languages/kotlin/)、[Scala](https://axisvela.github.io/praxo-core/zh-CN/languages/scala/) |
| .NET | [C# SDK](https://axisvela.github.io/praxo-core/zh-CN/languages/csharp/)、[Visual Basic 示例](docs/languages/visual-basic.md) |
| 其他语言 | [完整语言实现目录](docs/zh-CN/languages/index.md) |

源码发布、包管理器发布、一致性测试和生产验证是不同状态。请按各语言页面安装，
并阅读[支持政策](docs/zh-CN/languages/support.md)，不能从源码标签推断完整功能一致或包仓库可用。

## 可运行示例

| 目标 | 示例 |
| --- | --- |
| 模型、工具与流式输出 | [Quickstart](examples/quickstart) |
| 审批与拒绝边界 | [Governed workspace](examples/governed-workspace) |
| 检查点恢复 | [Checkpoint](examples/checkpoint) |
| 策略控制命令执行 | [Sandbox](examples/sandbox) |
| 委派任务 | [Multi-agent](examples/multiagent) |
| 使用自己的适配器嵌入 | [Integrator](examples/integrator) |

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

PRAXO-CORE 是独立的 MIT 框架。

可使用自己的适配器，或接入[可选 AxisVela 生态](docs/zh-CN/integrations/ecosystem.md)。
具体模块范围和限制见[适配器目录](docs/zh-CN/integrations/index.md)。

## 版本与贡献

核心 `2.5.0` 新增 conformance 包并加固本地 VFS。适配器和 SDK 独立版本化。

- [最新发布说明](docs/zh-CN/releases/2.5.0.md)
- [版本历史](docs/zh-CN/releases/index.md)
- [兼容政策](docs/zh-CN/project/compatibility-policy.md)
- [v2 迁移](docs/zh-CN/project/migration-v2.md)
- [公开路线图](ROADMAP.md)
- [贡献指南](CONTRIBUTING.md)
- [安全问题报告](SECURITY.md)

## 许可证

MIT。参见 [LICENSE](LICENSE) 与[来源说明](docs/zh-CN/project/provenance.md)。
