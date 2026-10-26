# 语言实现规范

本文定义公开的贡献要求，不承诺语言扩展排期。当前实现范围以
[语言支持矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)为准。

## 选择合适的实现类型

- Core：实现声明的原生核心契约与 Agent 行为。
- Wire：只实现声明的序列化与 wire 契约。
- Bridge：按[桥接契约](https://github.com/axisvela/praxo-core/blob/main/spec/bridge.md)委派执行。
- Sample：复用现有运行时软件包。

JavaScript 复用 TypeScript，Kotlin 和 Scala 复用 Java，Visual Basic 复用 .NET。
同一运行时不应在缺少具体消费者和维护者时重复实现 Agent 循环。

## 验证要求

| 类型 | 必需检查 |
| --- | --- |
| Core | 声明范围的全部核心向量组、parity 清单、API 快照、构建与语言测试 |
| Wire | 声明的 wire 向量子集、序列化与错误码测试 |
| Bridge | 消息边界、退出码、错误和桥接契约测试 |
| Sample | 使用宿主软件包编译或执行 |

新增原生循环需要明确的消费者和维护者。共享向量不能替代取消、并发、路径隔离等
安全敏感行为的专项测试。

## 文档与许可

每个交付的实现需要独立语言入口页、源码 README、安装或构建方法、契约版本、
限制与测试命令。源码标签和包管理器发布必须分开说明，范围变更同步更新矩阵和
parity 清单。

所有 SDK 保持 MIT，依赖必须具有兼容许可。提供商凭据、租户数据和产品专属逻辑
不属于 SDK。
