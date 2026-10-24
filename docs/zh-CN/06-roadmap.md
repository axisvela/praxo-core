# 路线图详情

公开路线图参见
[ROADMAP.md](https://github.com/axisvela/praxo-core/blob/main/ROADMAP.md)。

## 发布纪律

- `0.x` 可通过次要版本破坏接口。
- `1.0.0` 冻结导出的接口。
- 每次发布更新 `CHANGELOG.md` 和 `VERSION`。
- 每次发布说明支持的 PRAXOVELA 范围。

## 兼容性门禁

| 门禁 | 要求 |
| --- | --- |
| 0.2.0 | 每个基础能力都有一致性测试 |
| 0.3.0 | PRAXOVELA 可基于该模块构建 |
| 0.5.0 | 重启与重复触发测试通过 |
| 0.15.0 | 插件宿主、Manifest v1、契约 TCK、路径约束和上下文预算通过测试 |
| 0.16.0 | 规范包路径、废弃别名和导出 API 清单 |
| 1.0.0 | API 冻结、安全审查、外部集成方示例、SBOM/校验和 |
| 1.1.0 | 上下文管理对齐：摘要、卸载、`AGENTS.md`、提示词缓存钩子（2026-10-18 发布） |
| 1.2.0 | 委派/执行对齐：异步/fork 子 Agent、虚拟文件系统后端、delete/glob/grep（2026-10-18 发布） |
| 1.3.0 | Harness 配置、评分/评估中间件、可选 JS 解释器（2026-10-18 发布） |
| 1.4.0 | 结构化输出、工具选择、PII、fallback、重试和调用限额（2026-10-18 发布） |
| 1.5.0 | HITL approve/edit/reject/respond（2026-10-18 发布） |
| 1.6.0 | 能力包拆分、typed streams、会话恢复、checkpoint allowlist（2026-10-18 发布） |
| 1.7.0 | 上下文编辑与 todo/planning 中间件（2026-10-18 发布） |
| 2.0.0 | v2 模块路径，API 功能与 1.7.0 相同（2026-10-18 发布） |
| 2.1.0 | adapters、文档站、recipes、benchmark、参考应用（2026-10-22 发布） |
| 2.2.0 | 协议适配器、多 Agent 组合、示例、安全修复（2026-10-23 发布） |
| 2.3.0 | 事件驱动子任务等待、真实并发、有界调度（2026-10-23 发布） |
| 2.3.1 | gRPC 往返、Wait/Prune 快照、文档门禁（2026-10-23 发布） |
| 2.3.2 | provider/security recipes 加固、Gemini 候选隔离（2026-10-23 发布） |
| 2.3.3 | 最终工具授权、发布门禁失败传播、独立模块安全检查（2026-10-24 发布） |
| 2.3.4 | JSON Schema 子集语义与 HTTP 失败路径测试（2026-10-24 发布） |
| 2.3.5 | scheduler disable 等待 in-flight dispatch（2026-10-24 发布） |
| 2.3.6 | formatter 运行时与可变状态修复（2026-10-24 发布） |
| 2.4.0 | 采用面更新：流式 quickstart、MCP 资源/提示词示例、记忆召回基准（2026-10-24 发布） |

1.0 之后的项目是竞争力层面的 Harness 对齐，不是 1.0 的阻塞项。它们排在
稳定 API 和发布门禁之后。

当前已发布版本为 `2.4.0`，这是一次采用面更新，包含流式 quickstart、内存 MCP
资源/提示词示例和记忆召回基准，不改变导出 `pkg/...` API。`2.5.0` 是框架加固
候选版本，不声称外部采用或部署产品证据。

## 2.4 之后的框架优先级

`2.4.0` 已完成采用面。接下来的框架工作是验证、加固和稳定的集成契约，不改变
冻结的 `pkg/...` API：

- `v2.4.0` 的已发布版本 consumer 验证
- TOCTOU、Linux 进程树和 WASM CPU 限制的对抗性 containment 测试
- OpenTelemetry reference 示例（#3）
- VFS、memory、sandbox、event、policy、gateway、model、流式 model、tool 和
  retriever 的外部契约检查，以及统一 runner
- 事件与 OpenTelemetry schema 兼容规则（已发布）
- 与 RHEOVELA 的远程 worker 契约
- workspace/session 评估、契约、fake、一致性检查、E2B/Daytona 离线适配器
  与能力结论；实网验证仍待完成；提供商 SDK 不进入核心模块

## 长期技术方向

- **3-6 个月：** containment 加固、契约测试套件和远程 worker 契约。
- **6-12 个月：** 稳定事件/OpenTelemetry schema、兼容规则和独立实现。
- **12 个月以上：** 冻结 `pkg/...` API，每项功能都有可验证使用方，并保持 MIT
  边界。

产品采用、案例研究和市场推广不在本仓库跟踪。

## 已交付的采用面

- 流式 quickstart 与 reference app
- 事件驱动子 Agent 等待、真实 `flow.Parallel` 并发、有界多 Agent 监督
- OpenAI 兼容、MCP、OTel、Anthropic、Gemini、Harmovela、A2A 与多 Agent
  适配器/模块
- NOETIVELA、Mnemovela、GNOSIVELA、AEGIVELA、LIMENORA 与 RHEOVELA recipes
- 双语文档站、多 Agent 指南、采用指南与 recipes
- 基准、发布说明与已发布模块 consumer 检查

## 证据

- 单元测试
- 接口一致性测试
- 使用方构建测试
- 发布说明
- SBOM 与校验和
