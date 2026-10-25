# PRAXO-CORE 中文文档

[English README](https://github.com/axisvela/praxo-core/blob/main/README.md) |
[中文 README](https://github.com/axisvela/praxo-core/blob/main/README.zh-CN.md)

本目录是 PRAXO-CORE 文档的简体中文版本。英文文档从
[`docs/00-overview.md`](../00-overview.md) 开始。

| 文档 | 内容 |
| --- | --- |
| [快速开始](quickstart.md) | 使用 Ollama 或 OpenAI 兼容端点运行 Agent |
| [2.5.0 发布说明](releases/2.5.0.md) | conformance 包与本地 VFS 加固 |
| [2.4.0 发布说明](releases/2.4.0.md) | 流式 quickstart、MCP 示例与记忆召回基准 |
| [2.3.6 发布说明](releases/2.3.6.md) | formatter 运行时与可变状态修复 |
| [2.3.5 发布说明](releases/2.3.5.md) | scheduler disable 等待 in-flight dispatch |
| [2.3.4 发布说明](releases/2.3.4.md) | JSON Schema 语义修复与 HTTP 失败路径测试 |
| [2.3.3 发布说明](releases/2.3.3.md) | 最终工具授权、发布门禁及模块安全检查 |
| [2.3.2 发布说明](releases/2.3.2.md) | 版本重点、升级方式与验证结果 |
| [2.3.1 发布说明](releases/2.3.1.md) | 版本重点、升级方式与验证结果 |
| [2.3.0 发布说明](releases/2.3.0.md) | 版本重点、升级方式与验证结果 |
| [2.2.0 发布说明](releases/2.2.0.md) | 版本重点、升级方式与验证结果 |
| [2.1.0 发布说明](releases/2.1.0.md) | 版本重点、升级方式与验证结果 |
| [采用指南](adoption.md) | 评估、原型、生产清单与迁移注意事项 |
| [Recipes](recipes.md) | OpenAI 兼容、MCP、NOETIVELA、Mnemovela、GNOSIVELA 接入片段 |
| [适配器索引](adapters.md) | 模型、工具、协议适配器与模块 tag |
| [多 Agent 模式](13-multi-agent.md) | subagent 委派、边界与 RHEOVELA 分工 |
| [与其他 Go Agent 框架的对比](comparison.md) | 与 LangChainGo、Eino、Google ADK Go、Microsoft Agent Framework Go 的对比 |
| [基准测试](benchmarks.md) | Agent 循环回归基准与运行方法 |
| [AxisVela 生态集成](12-ecosystem.md) | 模型、记忆、Harmovela、GNOSIVELA 等组件的接入接缝 |
| [概览](00-overview.md) | 框架定位、边界与产品关系 |
| [架构](01-architecture.md) | Agent 循环、上下文、插件平面与设计规则 |
| [基础能力](02-primitives.md) | 各包的契约与典型适配器 |
| [多语言 SDK 设计](17-multilingual-sdk.md) | 共享契约、仓库布局、命名与一致性模型 |
| [多语言路线图](18-multilingual-roadmap.md) | Python、TypeScript、Java 的分阶段计划与门禁 |
| [集成](03-integration.md) | 与 PRAXOVELA 及外部集成方的集成方式 |
| [许可证与来源](04-license-and-provenance.md) | MIT 边界与代码来源规则 |
| [兼容性](05-compatibility.md) | 版本策略、API 稳定性与兼容性测试 |
| [路线图详情](06-roadmap.md) | 发布纪律与兼容性门禁 |
| [API 冻结清单](07-api-freeze.md) | 导出 API 范围与兼容性规则 |
| [安全模型](08-security.md) | 资产、信任边界、安全不变量与已知限制 |
| [发布流程](09-release.md) | 发布前门禁、SBOM、标签与发布 |
| [插件编写](10-plugin-authoring.md) | Manifest v1、进程/WASM 宿主与 TCK |
| [v2 迁移](11-migration-v2.md) | v2 模块路径迁移步骤 |
