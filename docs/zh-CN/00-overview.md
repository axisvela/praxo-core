# PRAXO-CORE 概览

PRAXO-CORE 是 PRAXOVELA 背后的 MIT 许可 Agent 框架。它的存在是为了让
AxisVela 产品和外部集成方能够构建受治理的 Agent，而无需重新实现 Agent
循环、提供商抽象、工具契约、记忆边界、事件边界或调度器契约。

## 它是什么

- 一个小型 Go 框架
- 提供商中立
- 工具驱动
- 感知记忆
- 可观测事件
- 受策略门控
- 可接入沙箱
- 可检查点化
- 可通过冻结的运行时插件契约扩展

## 它不是什么

- PRAXOVELA 产品
- 模型提供商
- 记忆数据库
- 工作流引擎
- 验证系统

## 关系

```text
praxo-core (MIT)
  |
  +-- PRAXOVELA (AGPL 产品)
  +-- 外部集成方
```

PRAXOVELA 仍是 AGPL 产品。MIT 框架是独立作品，因此可以在不产生 AGPL
义务的情况下嵌入。

## 运行时插件平面

`pkg/plugin` 定义契约类型、Manifest v1、生命周期状态机、受保护的适配器
注册表、按插件隔离的作用域、资源限制和遥测。进程与 WASM 宿主位于
`pkg/plugin/host`，通用桥接位于 `pkg/plugin/bridge`，一致性测试套件位于
`pkg/plugin/tck`。物化、签名信任、SBOM/证据和滚动更新仍归产品所有。
