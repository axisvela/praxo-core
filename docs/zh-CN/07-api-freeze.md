# API 冻结清单

**状态：** 针对 `2.0.0` 的 v2 模块路径审计；`2.1.0` 和 `2.2.0` 没有新增
`pkg/...` 声明。导出的表面与 `1.7.0` 在功能上一致。`1.0.0` 表面仍处于冻结
状态；新声明是增量式的。未发布版本新增 `SubagentManager.Wait` 和
`SubagentManager.Prune`。

## 审计结果

- 导出声明：**699**
- 没有文档注释的导出声明：**0**
- 范围：`pkg/...`；排除示例、测试、未导出的接收者方法和 testdata。
- 审计覆盖导出函数、导出类型上的方法、类型、常量和变量。

`pkg/agent` 根包保留能力包的类型别名，因此现有的 `agent.*` 导入保持源码
兼容，而实现位于能力子包中。

## 冻结范围

`1.0.0` 兼容性承诺覆盖：

- 导出接口及其方法集
- 导出结构体字段名和 JSON 标签
- 导出函数签名
- 导出常量和类型化字符串值
- 错误哨兵和类型化错误码
- 文档化为契约的线格式（插件 Manifest v1 和宿主信封）

不覆盖：

- 具体适配器、产品接线和 Janus/Vulcan 内部实现
- 未导出的辅助函数
- 示例
- 明确记录为实验性的字段

## 包清单

| 包 | 稳定表面 |
| --- | --- |
| `pkg/agent` | `Agent`、`Options`、`Profile`、`New`、能力类型的兼容别名 |
| `pkg/agent/context` | 预算、压缩、摘要、卸载、`AGENTS.md` |
| `pkg/agent/delegation` | 异步子 Agent 管理器、模式、等待与终态任务清理 |
| `pkg/agent/evaluation` | 评分与评估器 |
| `pkg/agent/hitl` | 中断动作、决策、处理器 |
| `pkg/agent/middleware` | 调用限制、回退、PII、结构化输出、工具选择、上下文编辑、待办 |
| `pkg/agent/stream` | 类型化流片段 |
| `pkg/agent/types` | 共享运行状态契约 |
| `pkg/checkpoint` | `Checkpoint`、`Store`、恢复类型 |
| `pkg/event` | `Event`、`Sink`、多路/过滤/发布者 Sink |
| `pkg/flow` | `Runnable`、`Chain`、`Parallel` |
| `pkg/formatter` | `Formatter`、检测/执行注册表 |
| `pkg/httpclient` | 支持重试的客户端以及认证/追踪选项 |
| `pkg/memory` | `Store`、`Record`、`Frame`、上下文组装器 |
| `pkg/model` | `Model`、`Provider`、消息、工具规格、响应格式、`CacheHint`、`ProviderProfile` |
| `pkg/plugin` | Manifest v1、契约类型、生命周期、注册表、作用域、限制、遥测 |
| `pkg/plugin/bridge` | 宿主到提供商的适配器和编解码器 |
| `pkg/plugin/host/process` | 进程宿主和平台监督器 |
| `pkg/plugin/host/wasm` | WASM 宿主和 guest ABI |
| `pkg/plugin/tck` | 生命周期、注册表和宿主一致性检查 |
| `pkg/policy` | `Hook`、`Decision`、`PathChecker`、路径授权 |
| `pkg/prompt` | `Template`、`ChatTemplate` |
| `pkg/retriever` | `Document`、`Retriever` |
| `pkg/sandbox` | `Sandbox`、`Spec`、`Result`、可选 `Interpreter` |
| `pkg/scheduler` | 调度定义和引擎 |
| `pkg/tool` | `Tool`、`Registry`、中间件、重试、网关 |
| `pkg/tool/jsonschema` | JSON Schema 校验器 |
| `pkg/vfs` | `Backend`、条目、匹配、可选执行器 |
| `pkg/vfs/localfs` | 受限本地目录后端 |
| `pkg/vfs/vfstools` | 由 vfs 后端支持的 `fs.*` 工具 |
| `pkg/toolcall` | 工具调用解析与标记清理 |

## 废弃别名

以下路径在 `0.16.0` 中废弃：

| 废弃路径 | 规范路径 |
| --- | --- |
| `pkg/output` | `pkg/toolcall` |
| `pkg/format` | `pkg/formatter` |
| `pkg/tool/schema` | `pkg/tool/jsonschema` |

PRAXOVELA 在 `0.16.0` 中迁移到规范路径。别名在 `1.0.0` 中移除；发布说明和
迁移条目位于 `docs/05-compatibility.md`。

## 兼容性规则

- 允许在次要版本中添加导出变更。
- 在 `1.0.0` 之后，删除或更改导出签名/字段需要主要版本。
- 接口新增需要主要版本，除非该接口被记录为可扩展。
- 导出结构体上的 JSON 标签是契约的一部分。
- 类型化常量字符串值是契约的一部分。

## 已解决的决定

1. `toolcall.ToolCall` 在 1.0 中保留 `Operation`、`Resource`、`Risk`、
   `Reason` 和 `IdempotencyKey`，作为可选透传的产品元数据。解析器不解释
   它们；删除它们会破坏 PRAXOVELA 的产品 API。在 2.0 中重新审视。
2. `checkpoint.Message` 有意保持为无依赖的序列化形态，而不是
   `model.Message` 的别名。
3. `tool.Gateway` 是产品拥有的外部网关（如 Janus）的接缝。
   `pkg/plugin/bridge` 是 `plugin.Host` 实现的接缝。两个包的文档都说明了
   这一区别。
4. 废弃别名在 `1.0.0` 中移除；PRAXOVELA 已在 `0.16.0` 中迁移。

## 1.0 门禁清单

- [x] 导出 API 清单
- [x] 每个导出声明都有文档注释
- [x] 开放问题已解决并记录
- [x] 针对 `0.16.0` 的 API 差异审查
- [x] 兼容性和迁移说明已发布
- [x] 已审查 `0.16.0 -> 1.0.0` 差异：仅移除三个废弃别名包；无其他导出变更
- [x] 框架威胁模型和安全加固（独立审查待完成）
- [x] 外部集成方示例
- [x] SBOM/校验和/发布检查工具已在本地验证
- [x] Linux/Windows/macOS CI 和竞态检测已观察到通过（2026-10-18）
- [x] 已发布带 SBOM/校验和的版本（附注标签；GPG 签名不可用）
