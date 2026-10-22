# PRAXO-CORE

[English](README.md) | [简体中文](README.zh-CN.md)

[![CI](https://github.com/axisvela/praxo-core/actions/workflows/ci.yml/badge.svg)](https://github.com/axisvela/praxo-core/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-axisvela.github.io-blue)](https://axisvela.github.io/praxo-core/)
[![Go Reference](https://pkg.go.dev/badge/github.com/axisvela/praxo-core/v2.svg)](https://pkg.go.dev/github.com/axisvela/praxo-core/v2)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**面向 AxisVela 生态的公开、MIT 许可 Agent 框架。**

PRAXO-CORE 提供 PRAXOVELA 及其他 AxisVela Agent 背后的可复用基础能力：
模型、工具、记忆、事件、调度、策略、沙箱、检查点、运行时插件平面以及
Agent 循环。它是框架，不是产品。

> **一句话：** 构建受治理的 Agent，无需重复实现循环、模型提供商抽象、
> 工具契约或记忆/事件边界。

**对比：** [PRAXO-CORE 与其他 Go Agent 框架](docs/zh-CN/comparison.md)
（LangChainGo、Eino、Google ADK Go、Microsoft Agent Framework Go）。

## 框架，而非产品

| 层级 | 说明 | 许可证 |
| --- | --- | --- |
| `praxo-core` | 可复用的 Agent 框架与契约（PRAXOVELA 家族） | MIT |
| PRAXOVELA | 构建于该框架之上的可运行 Agent 运行时产品 | AGPL-3.0 |

MIT 边界使 PRAXOVELA 和外部产品可以嵌入该框架，而无需继承 AGPL
义务。PRAXOVELA 仍是 AGPL 产品。

## 适用场景

PRAXO-CORE 适合需要受治理 Agent 循环的产品，并要求明确的策略、沙箱、检查点、
记忆、事件和插件边界。如果你希望把这些契约嵌入自己的运行时，同时把提供商和
产品适配器掌握在自己手里，它是合适的选择。

它不是托管式 Agent 服务、模型提供商、向量数据库或开箱即用的聊天 UI。

## AxisVela 生态

PRAXO-CORE 是 AxisVela 家族的框架层，不绑定单一产品：同一组接口可以将模型、
记忆、事件、检索、策略、沙箱、工具和图执行接入对应的 AxisVela 组件。具体
适配器和凭据由产品或集成方持有。

| 生态组件 | PRAXO-CORE 接缝 | 典型适配器 |
| --- | --- | --- |
| 模型与推理路由 | `pkg/model`（`Model`、`Provider`、`ModelRouter`、`ProviderProfile`） | NOETIVELA（NOETIVELA-open）/ PRAXOVELA 提供商路由器 |
| 记忆 | `pkg/memory`（`Store`、`ContextAssembler`） | Mnemovela |
| 事件 | `pkg/event`（`Sink`、`PublisherSink`） | Harmovela / Argus Trace |
| 检索 | `pkg/retriever`（`Retriever`、`Document`） | GNOSIVELA / Mnemovela |
| 策略 | `pkg/policy`（`Hook`、`PathChecker`） | AEGIVELA / Archon Guard |
| 沙箱 | `pkg/sandbox`（`Sandbox`、`Interpreter`） | Vulcan Forge |
| 工具 | `pkg/tool`（`Tool`、`Gateway`） | Janus Gateway / LIMENORA |
| 图执行 | `pkg/agent`、`pkg/agent/stream` | RHEOVELA |
| 产品运行时 | 所有接口 | PRAXOVELA |

NOETIVELA 是 AxisVela 的推理基础设施（inference fabric），可以通过 `model.Model` 或 `model.Provider`
适配器接入模型接缝。其他 AxisVela 控制平面（身份、保障、HITL、能力、孪生、
规划、协调）通过工具、事件或产品运行时适配器接入，而不是核心基础能力。

适配器是可选的，且归产品所有；框架从不导入产品代码。参见
[AxisVela 生态集成](docs/zh-CN/12-ecosystem.md)、
[适配器骨架](examples/ecosystem)、
[可运行接线示例](examples/ecosystem/cmd/demo) 与
[真实 NOETIVELA SDK 示例](examples/ecosystem-sdk)。

## 模块

`github.com/axisvela/praxo-core/v2`（v2 语义导入路径）。尚未迁移的使用方
仍可使用 `v1` 标签；参见 [v2 迁移指南](docs/11-migration-v2.md)。

## 快速开始

需要 Go 1.26+ 和一个 OpenAI 兼容端点。在本仓库中运行：

```bash
# Ollama（无需 API Key）
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
GOWORK=off go run ./examples/quickstart

# 任意 OpenAI 兼容端点
export PRAXO_BASE_URL=https://api.openai.com/v1
export PRAXO_API_KEY=...
export PRAXO_MODEL=gpt-4o-mini
GOWORK=off go run ./examples/quickstart
```

PowerShell 使用 `$env:PRAXO_BASE_URL = "..."`，变量名相同。可通过
`PRAXO_PROMPT` 修改请求内容。模型适配器只使用标准库，不需要提供商 SDK；
示例展示了工具调用、事件和策略。

可选适配器：

- [`adapters/openaicompat`](adapters/openaicompat) - 仅用标准库的
  OpenAI 兼容模型适配器
- [`adapters/mcp`](adapters/mcp) - 可选的 MCP 工具网关模块

SDK 集成示例参见 [`examples/ecosystem-sdk`](examples/ecosystem-sdk)
（NOETIVELA、Mnemovela、GNOSIVELA）。

## 基础能力

- `pkg/model` - 模型/提供商抽象与消息。
- `pkg/tool` - 工具契约与注册表；`pkg/tool/jsonschema` 校验 schema。
- `pkg/toolcall` - 模型输出中的工具调用解析与标记清理。
- `pkg/memory` - 记忆与上下文接口。
- `pkg/event` - 事件信封与 Sink。
- `pkg/scheduler` - 调度定义与调度器引擎。
- `pkg/policy` - 决策钩子、授权边界与路径约束。
- `pkg/sandbox` - 执行沙箱接口。
- `pkg/checkpoint` - 持久化运行快照与恢复存储契约。
- `pkg/httpclient` - 供适配器共享的、支持重试的 HTTP 传输层。
- `pkg/formatter` - 语言格式化器检测与执行。
- `pkg/flow` - Runnable、Chain 与 Parallel 组合。
- `pkg/prompt` - 提示词与聊天模板。
- `pkg/retriever` - 文档检索契约。
- `pkg/vfs` - 虚拟文件系统后端契约、受限本地后端与文件系统工具。
- `pkg/plugin` - 运行时插件契约、Manifest v1、生命周期、注册表、宿主与一致性测试套件。
- `pkg/agent` - 受治理的 Agent 循环，包含中间件、预算、上下文压缩与子 Agent 管理。能力包位于 `pkg/agent/{types,context,delegation,evaluation,hitl,middleware,stream}`；根包别名保持 `agent.*` 导入源码兼容。

## 与其他 Go Agent 框架的对比

Go Agent 生态中已有多个优秀框架。下表基于 2026 年 10 月的公开文档做高层定位，
上游项目迭代较快，采用前请核实最新细节。

| | PRAXO-CORE | LangChainGo | Eino | Google ADK Go | Microsoft Agent Framework Go |
| --- | --- | --- | --- | --- | --- |
| 主要定位 | 面向嵌入的受治理 Agent 运行时基础能力 | LangChain 风格的可组合 LLM 应用 | 带图编排与 ADK 的 LLM 应用框架 | 代码优先的 Agent 工具包，针对 Gemini 优化但模型无关 | 生产级 Agent 与多 Agent 工作流（公开预览） |
| AxisVela 生态 | 为 NOETIVELA、Mnemovela、Harmovela、GNOSIVELA、AEGIVELA、RHEOVELA、LIMENORA 提供一等接缝 | 自定义适配器/工具 | 自定义适配器/工具 | 自定义适配器/工具 | 自定义适配器/工具 |
| 编排 | 单 Agent 循环、中间件、子 Agent、`flow` Chain/Parallel | Chains、Agents、Tools | Graph/Workflow、ReAct `ChatModelAgent`、`DeepAgent` 多 Agent | Workflow Agents、图工作流、多 Agent 组合 | 图工作流：顺序、并发、群组、路由、子工作流 |
| 模型提供商 | 提供商中立的 `model.Model`；NOETIVELA/PRAXOVELA 适配器 | 丰富的内置提供商 | 通过 `eino-ext` 扩展 | Gemini 优先；OpenAI 适配器；模型无关 | Foundry、Azure、OpenAI、Anthropic、Gemini、Copilot |
| 工具与 MCP | 工具契约、JSON Schema、重试、网关；Janus/LIMENORA 网关；MCP 客户端由使用方提供 | 工具；MCP 非一等支持 | 工具；通过 `eino-ext` 支持 MCP | 丰富工具、MCP Toolset、A2A | 工具、MCP、A2A、AG-UI |
| 记忆与 RAG | 接口与检索契约；Mnemovela 记忆、GNOSIVELA 检索 | Memory、文档加载器、向量存储 | Retriever 与上下文组件 | Sessions、Memory、Artifacts | Memory、文本搜索/RAG、向量存储 |
| 治理与扩展 | 策略钩子、AEGIVELA 策略、路径约束、沙箱接缝、检查点、HITL、进程/WASM 插件平面、事件 Sink | Callbacks | HITL 中断/恢复、Callbacks | 生命周期插件钩子、认证、遥测 | 检查点、工具审批/HITL、OpenTelemetry |
| 许可证 | MIT | MIT | Apache-2.0 | Apache-2.0 | MIT |

PRAXO-CORE 刻意保持底层：不捆绑提供商 SDK、向量数据库或 MCP 客户端。它也是
表中唯一为 AxisVela 提供一等接缝的框架；其他框架仍可通过自定义适配器或工具
接入 AxisVela。需要可嵌入、MIT 许可的治理与运行时边界，或需要原生接入
NOETIVELA、Mnemovela、Harmovela、GNOSIVELA、AEGIVELA、RHEOVELA、LIMENORA
时，选择 PRAXO-CORE；需要开箱即用的集成与编排模式时，可选择 LangChainGo、
Eino 或 ADK。定位与选型建议参见 [完整对比](docs/zh-CN/comparison.md)。

## 示例

```go
ag, err := agent.New(agent.Options{
    Model:    myModel,
    Tools:    tools,
    Events:   sink,
    Policy:   hook,
    MaxSteps: 8,
})
if err != nil {
    return err
}
result, err := ag.Run(ctx, agent.Session{
    ID: "session-1",
    TenantID: "acme",
    WorkspaceID: "default",
}, "Inspect the failing test and propose a fix")
```

自包含的外部集成示例参见
[examples/integrator](examples/integrator/main.go)；带受限 VFS 工具、策略、记忆
和事件的 workspace Agent 参见 [examples/reference](examples/reference)。

## 状态

`2.0.0` 于 2026-10-18 发布。该版本仅将模块路径改为
`github.com/axisvela/praxo-core/v2`；导出的 API 与 `1.7.0` 在功能上完全一致
（`api/2.0.0.txt`；与 `1.7.0` 的差异仅为模块路径）。`1.0.0` 的 API 冻结仍然有效，
规范包路径为 `pkg/toolcall`、`pkg/formatter` 和 `pkg/tool/jsonschema`。`1.x`
系列新增了插件宿主、一致性测试套件、Manifest v1、路径约束、上下文预算压缩、
上下文摘要/卸载、VFS 工具、异步子 Agent、结构化输出、PII 脱敏、HITL 决策、
类型化流以及待办规划。该框架提取自 PRAXOVELA 经过验证的运行时。

## 文档

[文档站](https://axisvela.github.io/praxo-core/) |
[中文文档目录](docs/zh-CN/README.md)

- [中文文档目录](docs/zh-CN/README.md)
- [采用指南](docs/zh-CN/adoption.md)
- [采用计划](docs/zh-CN/13-adoption-plan.md)
- [Recipes](docs/zh-CN/recipes.md)
- [与其他 Go Agent 框架的对比](docs/zh-CN/comparison.md)
- [基准测试](docs/zh-CN/benchmarks.md)
- [AxisVela 生态集成](docs/zh-CN/12-ecosystem.md)
- [概览](docs/zh-CN/00-overview.md)
- [架构](docs/zh-CN/01-architecture.md)
- [基础能力](docs/zh-CN/02-primitives.md)
- [集成](docs/zh-CN/03-integration.md)
- [许可证与来源](docs/zh-CN/04-license-and-provenance.md)
- [兼容性](docs/zh-CN/05-compatibility.md)
- [v2 迁移](docs/zh-CN/11-migration-v2.md)
- [安全策略](SECURITY.md)
- [API 冻结清单](docs/zh-CN/07-api-freeze.md)
- [安全模型](docs/zh-CN/08-security.md)
- [发布流程](docs/zh-CN/09-release.md)
- [插件编写](docs/zh-CN/10-plugin-authoring.md)
- [路线图详情](docs/zh-CN/06-roadmap.md)
- [路线图](ROADMAP.md)

内部提取规划与产品家族排期位于私有 PRAXOVELA-EE 仓库。

## 许可证

MIT。参见 [LICENSE](LICENSE)。
