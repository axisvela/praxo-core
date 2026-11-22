# PRAXO-CORE 概览

PRAXO-CORE 是 PRAXOVELA 及 AKROVELA 等其他嵌入它的 AxisVela 产品背后的 MIT
许可 Agent 框架。它的存在是为了让产品和外部集成方能够构建受治理的 Agent，
而无需重新实现 Agent 循环、提供商抽象、工具契约、记忆边界、事件边界或调度器契约。

## 它是什么

- 一个 Go 参考框架，并提供 Python、TypeScript、Java、Rust、C#、R 等独立版本化的
  Core 实现
- 提供商中立
- 工具驱动
- 感知记忆
- 可观测事件
- 受策略门控
- 可接入沙箱
- 可检查点化
- 可通过冻结的运行时插件契约扩展

## 今天能构建什么

用唯一的[任务到路径表](index.md)选择任务和证明该任务的层级。语言入口按
开发者今天能构建什么分组，而不只按契约层级：

- **发布包治理 Starter：** Go、Python、TypeScript 和 Java。安装、运行确定性模型，并用
  治理负向检查证明 allow/deny。
- **发布包 allow/deny Starter：** Ruby、PHP、Elixir 和 Lua。这些扩展语言 Starter 证明
  安装和确定性 allow/deny，不包含完整四语言治理矩阵。
- **发布包或源码发布并可运行示例：** Rust、C#、R、Dart、Erlang、Haskell、Perl 和
  PowerShell。安装前先核对 Registry 版本。
- **源码 Core 与确定性示例：** C、C++、Fortran、COBOL、Julia、MATLAB/Octave、Swift、
  D、Nim、V、Zig、OCaml、Objective-C 和 Delphi / Free Pascal。部分尚无 Registry
  发布或上游审核仍在进行。
- **共享运行时 Sample 与 Bridge：** JavaScript、Kotlin、Scala、Groovy、Clojure、
  Visual Basic 和 F# 使用宿主 Core；Shell、Lisp、Tcl 和 Prolog 使用 Bridge 运行时。

精确分组见[语言实现](../languages/index.md)，包状态见
[Registry 发布状态](../languages/registry-status.md)。这些路径不代表生产就绪或与
Go 完全等价。

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
  +-- AKROVELA (AGPL 产品)
  +-- 外部集成方
```

PRAXOVELA 与 AKROVELA 仍是定位不同的独立 AGPL 产品。两者都将 MIT 框架作为
自身产品组件嵌入；框架是独立作品，因此可以在不产生 AGPL 义务的情况下嵌入。
Core 不获取它们的产品状态或领域权威。

## 多语言 Core

Go 模块是参考实现。Python、TypeScript、Java、Rust、C#、R 等 Core 实现共享
`spec/` 中的一份语言无关契约，并由一致性测试强制执行。各语言 wire 形状完全相同；
源码 API 一对一映射，但使用符合语言习惯的名称。C、C++、Fortran、COBOL、Ruby、
PHP、Elixir、Erlang 和 Lua 等实现按各自声明的范围提供 Core 或聚焦实现。设计见
[多语言 Core 设计](../contributing/core-design.md)；实现类型、分发与限制见
[Core 支持政策](../languages/support.md)。

## 运行时插件平面

`pkg/plugin` 定义契约类型、Manifest v1、生命周期状态机、受保护的适配器
注册表、按插件隔离的作用域、资源限制和遥测。进程与 WASM 宿主位于
`pkg/plugin/host`，通用桥接位于 `pkg/plugin/bridge`，一致性测试套件位于
`pkg/plugin/tck`。物化、签名信任、SBOM/证据和滚动更新仍归产品所有。
