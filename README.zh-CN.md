# PRAXO-CORE

[English](README.md) | [简体中文](README.zh-CN.md)

**面向 AxisVela 生态的公开、MIT 许可 Agent 框架。**

PRAXO-CORE 提供 PRAXOVELA 及其他 AxisVela Agent 背后的可复用基础能力：
模型、工具、记忆、事件、调度、策略、沙箱、检查点、运行时插件平面以及
Agent 循环。它是框架，不是产品。

> **一句话：** 构建受治理的 Agent，无需重复实现循环、模型提供商抽象、
> 工具契约或记忆/事件边界。

## 框架，而非产品

| 层级 | 说明 | 许可证 |
| --- | --- | --- |
| `praxo-core` | 可复用的 Agent 框架与契约（PRAXOVELA 家族） | MIT |
| PRAXOVELA | 构建于该框架之上的可运行 Agent 运行时产品 | AGPL-3.0 |

MIT 边界使 PRAXOVELA 和外部产品可以嵌入该框架，而无需继承 AGPL
义务。PRAXOVELA 仍是 AGPL 产品。

## 模块

`github.com/axisvela/praxo-core/v2`（v2 语义导入路径）。尚未迁移的使用方
仍可使用 `v1` 标签；参见 [v2 迁移指南](docs/11-migration-v2.md)。

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
[examples/integrator](examples/integrator/main.go)。

## 状态

`2.0.0` 于 2026-10-18 发布。该版本仅将模块路径改为
`github.com/axisvela/praxo-core/v2`；导出的 API 与 `1.7.0` 在功能上完全一致
（`api/2.0.0.txt`；与 `1.7.0` 的差异仅为模块路径）。`1.0.0` 的 API 冻结仍然有效，
规范包路径为 `pkg/toolcall`、`pkg/formatter` 和 `pkg/tool/jsonschema`。`1.x`
系列新增了插件宿主、一致性测试套件、Manifest v1、路径约束、上下文预算压缩、
上下文摘要/卸载、VFS 工具、异步子 Agent、结构化输出、PII 脱敏、HITL 决策、
类型化流以及待办规划。该框架提取自 PRAXOVELA 经过验证的运行时。

## 文档

- [概览](docs/00-overview.md)
- [架构](docs/01-architecture.md)
- [基础能力](docs/02-primitives.md)
- [集成](docs/03-integration.md)
- [许可证与来源](docs/04-license-and-provenance.md)
- [兼容性](docs/05-compatibility.md)
- [v2 迁移](docs/11-migration-v2.md)
- [安全策略](SECURITY.md)
- [API 冻结清单](docs/07-api-freeze.md)
- [安全模型](docs/08-security.md)
- [发布流程](docs/09-release.md)
- [插件编写](docs/10-plugin-authoring.md)
- [路线图详情](docs/06-roadmap.md)
- [路线图](ROADMAP.md)

内部提取规划与产品家族排期位于私有 PRAXOVELA-EE 仓库。

## 许可证

MIT。参见 [LICENSE](LICENSE)。
