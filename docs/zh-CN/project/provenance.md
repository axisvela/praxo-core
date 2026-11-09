# 许可证与来源

PRAXO-CORE 采用 MIT 许可。参见
[LICENSE](https://github.com/axisvela/praxo-core/blob/main/LICENSE)。

## 来源规则

- 只有 AxisVela 拥有的代码，或获得明确重新许可授权的代码，才可以进入本仓库。
- **AxisVela 授权的内部复用：** PRAXOVELA 实现代码可以在 AxisVela 维护的内部
  重新许可记录下复制到 PRAXO-CORE。
- 记录每个被复制包的源路径和源提交。
- 不要导入仅限 AGPL 的第三方包。
- 保留版权声明和第三方声明。
- 贡献需要 CLA 或等效的重新许可授权。

## AKROVELA Recipe 的限定复用

2026-11-09 获得明确授权：将选定的 AxisVela 自有 AKROVELA 恢复机制去产品化，
以 MIT 纳入应用 recipe。授权不覆盖仅限 AGPL 的第三方代码，也不改变 AKROVELA
自身的许可证。内部授权记录保留批准依据和评审范围。

来源为 `axisvela/akrovela` 提交
`bc8ef5fd0ae34a81debf9d83a494a467adc46f36` 的
`backend/internal/satellite/agent.go`、`journal.go` 和 `agent_test.go`。
目标为 `examples/recipes/long-running-go/` 中的 `execution.go`、
`execution_test.go`、`execution_process_test.go` 及恢复说明。
只保留通用的持久化启动意图、不确定结果和重试安全机制；不导入产品包，
不新增 Core 公共 API，也不转移产品权威。

## 为什么采用 MIT

该框架旨在被以下对象嵌入：

- PRAXOVELA（AGPL 产品）
- 外部产品

MIT 使框架保持可复用，同时产品保留各自的许可证。

## 与 PRAXOVELA 的关系

PRAXOVELA 仍为 AGPL-3.0。它使用 MIT 框架，但不会重新许可产品。框架是位于
独立仓库中的独立作品。

反方向在同一内部重新许可记录下获得授权：PRAXOVELA 实现代码可以复制到
PRAXO-CORE 并以 MIT 重新许可。复制时必须记录源路径和提交。

## Fortran 正则依赖

Fortran `0.3.0` 源码通过原创 MIT C ABI wrapper 使用 RE2
2025-11-05（BSD-3-Clause）和 Abseil 20250512.1（Apache-2.0）。构建固定到
上游完整提交，不把第三方源码复制进本仓库；安装 wrapper 时同时安装两份原始
许可证。框架的 MIT 许可不替代这些依赖及 C++ 运行时的分发义务。
详见[依赖记录](https://github.com/axisvela/praxo-core/blob/main/language/fortran/native/DEPENDENCIES.md)。
