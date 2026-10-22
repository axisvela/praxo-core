# 兼容性

## 版本管理

- `v2` 使用 `github.com/axisvela/praxo-core/v2` 模块路径。
- 尚未迁移的使用方仍可使用 v1。
- v2 导出的 API 与 v1.7.0 在功能上一致；参见
  [v2 迁移](11-migration-v2.md)。

- 框架版本从 `0.x` 开始。
- PRAXOVELA 产品版本独立。
- 外部使用方声明支持的框架范围。
- 在 `1.0.0` 之前，破坏性变更需要次要版本升级。

## 使用方矩阵

| 使用方 | 预期集成方式 |
| --- | --- |
| PRAXOVELA | 嵌入框架基础能力；仍为 AGPL |
| 外部产品 | 直接实现接口 |

## API 稳定性

导出的接口是稳定表面。具体适配器和内部辅助函数可能在次要版本之间变化。

`0.16.0` 中添加的规范包路径是 `pkg/toolcall`、`pkg/formatter` 和
`pkg/tool/jsonschema`。之前的路径（`pkg/output`、`pkg/format`、
`pkg/tool/schema`）是废弃别名。PRAXOVELA 已在 `0.16.0` 完成迁移；
这些别名在 `1.0.0` 中移除，详见
[API 冻结清单](07-api-freeze.md)。

冻结的插件 v1 表面包括：

- Manifest v1（`pkg/plugin.ParseManifest`）
- 契约类型与 `Host.Invoke` 边界
- 生命周期转换表
- 受保护的 `AdapterRegistry`
- 进程/WASM 线格式信封
- 契约级 TCK

物化、签名验证、SBOM/证据、信任存储和滚动更新归产品所有，可以独立演进。

## 兼容性测试

每个使用方应维护：

- 编译期接口一致性
- Agent 循环的冒烟测试
- 策略拒绝测试
- 事件 Sink 测试
- 使用记忆适配器时的记忆适配器测试
- 使用插件宿主时通过 `pkg/plugin/tck` 进行的一致性测试
