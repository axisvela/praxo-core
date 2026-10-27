# 语言实现规范

本文定义公开的贡献要求，不承诺语言扩展排期。当前实现范围以
[语言支持矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)为准。

## 目标是 Framework，声明反映当前阶段

- Framework：能够支持共享核心契约的独立语言实现的默认最终目标；继续使用
  `Core` 作为既有范围标识。
- Wire：向 Framework 演进的中间阶段，当前只实现声明的序列化与 wire 范围。
  公开 API 与行为尚未实现并验证之前，不能宣传为完整 Framework。
- Bridge：按[桥接契约](https://github.com/axisvela/praxo-core/blob/main/spec/bridge.md)委派执行。
- Sample：复用现有运行时软件包。

只有明确记录的语言或运行时技术限制确实阻止完整 Framework 实现时，才以 Wire
为最终范围。必须说明无法支持的具体要求及证据，并在语言支持文档和矩阵中明确
标注例外，不能把工具链暂缺、开发不完整、需求少或维护者缺失当作语言能力限制。

默认目标不是发布承诺，也不允许跳过消费者、维护、一致性、安全与许可门槛。
当前阶段、最终目标、功能覆盖、验证和分发状态是彼此独立的信息。

JavaScript 复用 TypeScript，Kotlin、Scala、Groovy 和 Clojure 复用 Java，Visual Basic 和 F# 复用 .NET，OpenCL 示例复用 C SDK。
同一运行时不应在缺少具体消费者和维护者时重复实现 Agent 循环。

## 验证要求

| 类型 | 必需检查 |
| --- | --- |
| Core | 声明范围的全部核心向量组、parity 清单、API 快照、构建与语言测试 |
| Wire | 声明的 wire 向量子集、序列化与错误码测试 |
| Bridge | 消息边界、退出码、错误和桥接契约测试 |
| Sample | 使用宿主软件包编译或执行 |

新增原生循环需要明确的消费者和维护者；这决定实施顺序，不改变 Framework 最终目标。
共享向量不能替代取消、并发、路径隔离等
安全敏感行为的专项测试。

## 文档与许可

每个交付的实现需要独立语言入口页、源码 README、安装或构建方法、契约版本、
限制与测试命令。源码标签和包管理器发布必须分开说明，范围变更同步更新矩阵和
parity 清单。
Wire 条目应说明 Framework 目标，除非存在已记录的技术例外。不能只因最终目标是
Framework，或一致性运行器通过了核心向量，就把当前范围直接改成 Core。

所有 SDK 保持 MIT，依赖必须具有兼容许可。提供商凭据、租户数据和产品专属逻辑
不属于 SDK。
