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

JavaScript 复用 TypeScript，Kotlin、Scala、Groovy 和 Clojure 复用 Java，Visual Basic 和 F# 复用 .NET，OpenCL 示例复用 C Core。
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

## 行为覆盖层级

契约一致性与 agent 行为覆盖相互独立。行为层级如下：

| 层级 | 语言 | 规则 |
| --- | --- | --- |
| Agent-capable | Go、Python、TypeScript、Java、Rust、R、C# | 以全部二十个行为实验场景为目标；未覆盖的单元格必须明确标为 `unsupported` 并给出原因 |
| Extended | C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua | 只在有明确消费者和维护者时逐场景推进；不得仅为增加数量而新增场景或语言 |
| Optional | 其他已声明实现 | 默认不开展行为工作；晋级需要明确消费者、维护者和场景证据 |

R 和 C 已接入实验。C# 与 PHP 对部分场景只有套件级覆盖，R/C 只覆盖其原生套件实际断言的场景行。新增场景必须加入每个 agent-capable 实现，或在矩阵中保留明确的 unsupported 原因。套件级覆盖不等于场景级证据。

## 文档与许可

每个交付的实现需要独立语言入口页、源码 README、安装或构建方法、契约版本、
限制与测试命令。源码标签和包管理器发布必须分开说明，范围变更同步更新矩阵和
parity 清单。维护者确认后才记录支持等级；不要从成熟度、源码标签或注册表可用性推断官方支持。
Wire 条目应说明 Framework 目标，除非存在已记录的技术例外。不能只因最终目标是
Framework，或一致性运行器通过了核心向量，就把当前范围直接改成 Core。

所有 Core 保持 MIT，依赖必须具有兼容许可。提供商凭据、租户数据和产品专属逻辑
不属于 Core。
