# 公开路线图

当前核心版本为 `2.5.2`。这是**执行内核契约路线图**：说明 Core 自己拥有的契约和
已验证行为，并标明属于产品或集成方的证据。它不是交付排期，也不表示所有 Core
都具有每一项功能。

## 当前方向

优先证明行为，而不是增加语言、提供商或工具数量。每一行把 Core 自己的验收目标与
外部证据分开。以下是目标，不表示工作已经完成。

| 方向 | Core 验收目标 | 外部证据归属 |
| --- | --- | --- |
| 发布与验证完整性 | 文档和发布门禁与规范版本元数据一致；跳过项和旧报告不能被记为本次通过 | 发布操作方和 CI 保留原始运行记录 |
| 受治理集成 | 缺少必要控制、授权拒绝或安全依赖故障时阻止执行；最终工具参数仍受授权约束 | NOMIVELA、EIDOVELA、AEGIVELA 和 LIMENORA 提供注册表、身份、策略和网络服务；Core 提供接口、fake 和负向测试 |
| 上下文信任 | 来源与信任差异在 Core 的 assembly、compaction、offload 和 restore 中保留；恶意 memory、skill 和工具结果在 Core 测试中不会成为受信任指令 | PRAXOVELA 与记忆/检索产品提供真实来源和持久 lineage |
| 效果语义与恢复 | Core 区分意图、尝试执行、业务提交、无效果和未知结果；checkpoint 不是事务；幂等行为可测试 | RHEOVELA 拥有持久工作流、worker lease、fencing 和恢复；PRAXOVELA 拥有租户效果账本；不声明 exactly-once |
| 隔离能力 | Core 拥有的 VFS、路径、插件、进程宿主和 WASM 控制经过测试，并写明平台限制与剩余风险 | 部署环境的 OS/网络隔离与部署级独立评审属于产品或运营方 |
| 提供商与可观察性证据 | Core 提供事件/OpenTelemetry 映射、allowlist、fake-provider 一致性以及 workspace session 契约 | 真实 provider、collector/OTLP、采样和留存属于集成证据；两提供商复核是 workspace 契约晋级门禁 |
| 语言支持 | 分别报告契约一致性、行为覆盖和支持等级；agent-capable 实现以二十个场景为目标；未覆盖单元格保持显式 | 包发布与真实运行证据遵循 registry 和产品记录 |

受治理集成在 Core 中是契约工作。NOMIVELA、EIDOVELA、AEGIVELA、LIMENORA 和
RHEOVELA 分别拥有注册表、身份、策略、网络和持久工作流服务；Core 提供接口、
可测试 fake 和负向测试。归属边界见下文“生态边界”。

## 行为能力层级

行为覆盖与契约层级分开跟踪：

| 层级 | 语言 | 当前目标 |
| --- | --- | --- |
| Agent-capable | Go、Python、TypeScript、Java、Rust、R、C# | 全部二十个行为实验场景；缺口保持显式 |
| Extended | C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua | 仅在有明确消费者和维护者时逐场景推进 |
| Optional | 其他已声明实现 | 不在行为计划内；契约一致性不变 |

clean 十六语言报告为 320 passed、0 个显式 unsupported、无失败。全部十六个已接入语言在源码中均覆盖二十个场景；部分并行工具单元格把并发委托给调用方提供的批处理回调，Core 本身不创建线程。不要把 unsupported 当作失败或通过，也不要仅为提高数量而增加语言或场景。

边界设计见[受治理执行设计](../reference/governed-execution.md)。环境、配置、过程、数据、
结果和发现的记录要求见[测试证据规范](../contributing/test-evidence.md)。

## 验证边界

Core 测试验证框架行为；跨仓库测试仅验证实际执行的集成与版本。历史本地服务运行是有价值的
证据，但不证明当前发布版本、独立复现或生产就绪。

行为实验与兼容性报告会注明被测 revision。后续仅文档提交不会扩展该证据；为新 revision 引用报告前必须重跑或重新绑定。

新增共享安全或效果契约必须先有明确消费者和负向测试，再考虑公开 API。
身份签发、策略决策服务、效果账本和持久化工作流仍由集成层负责。
本设计本身不改变默认行为或公开 API。

## 生态边界

PRAXO-CORE 是可复用的执行内核，不是产品平台。PRAXOVELA 系列通过与其他消费者相同的
公开契约组合它。本节说明归属边界，不是产品路线图。

| 能力 | 归属 | Core 职责 |
| --- | --- | --- |
| 产品运行时、租户数据、UX、部署 | PRAXOVELA（AXON Core） | 暴露 agent、tool、policy、stream、checkpoint 和 workspace API；产品状态不进入框架 |
| 图/子图执行、持久工作流、worker lease、fencing、恢复 | RHEOVELA | 提供 agent node、session、stream 和 adapter 契约；不增加图运行时 |
| Agent 注册表、Agent ID、authority binding、发现 | NOMIVELA | 定义 registry client 边界；不运营注册表 |
| Agent 身份、注册、证明、PoP token、已验证上下文 | EIDOVELA | 定义身份验证 hook；不签发凭据 |
| 策略决策、执行授权、审批、撤销、obligations、安全证据 | AEGIVELA | 定义 authorizer、grant 和策略执行点；不运营 PDP 或持久审批存储 |
| 南北向网络边界与反向入口 | LIMENORA | 可部署在网关之后；不增加网络控制平面 |
| 能力治理、运行时 profile、记忆、事件传输 | MODUREGIS、SYNDOVELA、Mnemovela/GNOSIVELA、Harmovela | 仅在存在明确消费者和负向测试时提供可选 adapter 契约 |

身份签发、策略决策服务、效果账本、持久工作流引擎和网络网关仍由集成层负责。Core
测试不认证产品部署，产品集成也不扩大 Core API。

## 兼容承诺

保持 Go 公开 API 精简、MIT 边界完整，新契约需要消费者和测试。不能仅为移植 Core
扩大 Go API。参见[兼容政策](compatibility-policy.md)、[Core 支持](../languages/support.md)
与[语言规范](../contributing/language-policy.md)。

## 已交付内容

参见[版本历史](../releases/index.md)、[验证证据索引](verification-evidence.md)和
[完整变更日志](https://github.com/axisvela/praxo-core/blob/main/CHANGELOG.md)。
可选适配器的离线评估不等于真实生产验证。
