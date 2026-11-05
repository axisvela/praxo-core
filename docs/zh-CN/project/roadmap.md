# 公开路线图

当前核心版本为 `2.5.2`。这是**执行内核契约路线图**：说明 Core 自己拥有的契约和
已验证行为，并标明属于产品或集成方的证据。它不是交付排期，也不表示所有 Core
都具有每一项功能。

## 下一阶段方向

**规划更新：2026-11-05。** 下一阶段从实现数量转向正确采用与可验证集成：让使用者和
编程 Agent 能判断适用任务、安装已发布包、验证受治理行为，并在升级后继续保留依赖。

保持**可治理、可嵌入的 Agent 执行内核**定位。具身应用是可选集成方向，不将 Core
重新定义为机器人平台，也不声明内置完整规划器或安全系统。AxisVela 产品不是前置依赖，
独立消费者使用相同公开契约。

以下阶段是验收门槛，不是排期、版本分配或已实现 Profile。安全修复和现有支持承诺持续
推进；阶段不推迟维护，也不要求所有活动严格串行。

| 阶段 | 交付目标 | 验收门槛 |
| --- | --- | --- |
| 0. 建立基线 | 对应推荐包版本、消费者检查与证据；区分已实现、提案、实验和验证范围；建立采用任务基线 | 历史兼容性、当前推荐包、待发布候选分别记录证据；涉及契约修改前先澄清相关版本与兼容规则 |
| 1. 打通消费者路径 | Go、Python、TypeScript、Java 独立 Starter；使用已发布包、确定性模型、显式工具范围与允许/拒绝测试；提供任务型选型入口 | 运行不依赖源码检出、本地替换、未发布依赖、API Key 或外部模型服务；安装可访问 Registry；拒绝不产生工具副作用 |
| 2. 验证受治理集成 | 消费者可执行验收、集成配方、精简编程 Agent 指引、可选安装 Skill、准确的包描述 | 缺少必要控制或必需安全服务失效时拒绝；检查最终操作和审批编辑；未知结果不盲目重试 |
| 3. 验证长时操作 | 有明确消费者的单个集成，覆盖提交、查询、反馈、取消、幂等和断连恢复 | Run 取消不被误报为远端执行已停止；恢复先查询权威操作状态，再决定是否重复产生效果 |
| 4. 具身集成试点 | 一个明确消费者、一种中间件、一个端到端仿真及实验性具身集成 Profile | 分开记录接受、完成与效果验证；测试观测新鲜度、断连、重复提交和安全依赖失效；仿真不作为硬件或生产证据 |

首批四种 Starter 语言是采用试点范围，不降低 Rust、C#、R 或其他已声明实现的支持承诺。
有消费者和维护者依据时再扩展 Starter 与适配器，不以增加数量为目标。

[Go 独立消费者](../getting-started/consumer-go.md)、
[Python 独立消费者](../getting-started/consumer-python.md)、
[TypeScript 独立消费者](../getting-started/consumer-typescript.md)与
[Java 独立消费者](../getting-started/consumer-java.md)已实现四个试点语言的当前发布包
Starter。发布包安装、构建与确定性允许/拒绝检查已在 CI 通过，
[阅读导览](../getting-started/index.md)提供任务型选型指引。

因此，阶段 1 的消费者路径验收已对四个试点语言达成。这是集成证据，不是采用证据：
采用实验尚未运行，阶段 2-4 状态不变。试点语言集合不降低 Rust、C#、R 或其他实现的
支持承诺。

阶段 0 部分完成：状态词汇、共享 Wire 变更分类以及 Tool、Model、Checkpoint Wire 描述
已记录在[契约与证据状态](contract-status.md)。采用任务基线与跨产品权威核验仍未完成。

阶段 2 已从 Go、Python、TypeScript 与 Java 消费者可运行的治理负向测试开始，覆盖缺少
Policy/范围、最终参数重授权、审批编辑重授权与 Policy 服务失败。现已提供精简的
[编程 Agent 集成契约](../getting-started/coding-agents.md)、版本校验的
[包映射](../getting-started/agent-integration.json)、可运行的
[身份/策略配方](../guides/identity-policy.md)与工具中立的
[Skill 模板](https://github.com/axisvela/praxo-core/tree/main/agent-skills/praxo-integration)。
源 Registry 元数据已改进，四个试点页面已审计；已发布页面只随新版本更新。阶段 2 未完成：
Skill 安装/发现未验证、更多集成配方未完成、已发布 Registry 页面需新版本后才能验证。

阶段 3 已从 Go 消费者可运行的[长时操作配方](../guides/long-running-operations.md)
开始，覆盖幂等提交、权威恢复、取消请求/确认与 Run 取消。它使用内存 fixture；阶段 3
未完成：真实执行服务、持久恢复与效果验证仍未完成。

### 消费者与契约基线

仓库已有 published-consumer CI 和禁止本地模块替换的测试。本次规划核对时，Go 消费者
测试固定 Core `2.5.0`，推荐安装版本为 `2.5.2`。前者可以作为历史基线，但不能证明
当前推荐包路径已通过。应分别维护历史兼容性、当前推荐包和待发布候选检查，不能互相替代。

继续使用现有规范性 `spec/`，不另建竞争规范。Tool、Model、Checkpoint Wire 描述现已存在；
标记为 `"wire": false` 的条目描述 Go/源码投影，不是冻结的跨语言契约。源码、Wire 与行为
兼容规则已区分：Go 的可选字段加法不能自动授权共享 Wire 新增字段。可选 Profile 不能绕过
共享 Wire、parity 和 conformance 审查。

集成要求先通过现有接口实现。只有明确消费者证明了可复用缺口、负向测试覆盖该缺口，且
完成兼容性和语言影响评审后，才提升为公共 API。
[受治理执行设计](../reference/governed-execution.md)仍是验收提案，不是已实现的通用 Profile。

### 采用证据

发现与集成材料调整前先建立基线，分别运行以下实验：

| 轨道 | 回答的问题 |
| --- | --- |
| 自由选型 | 不指定 PRAXO-CORE 时，编程工具能否发现它，并按任务正确选择或排除？ |
| 指定集成 | 明确要求使用时，能否完成安装、构建、测试和约定的治理验收？ |
| 升级维护 | 依赖升级或应用变更后，生成的集成是否仍能正常工作？ |

分别记录发现、正确选型、安装、构建、治理测试、修复成本和可观察依赖留存。
区分首次生成即通过与整个自主会话最终通过。记录样本量、重复运行、工具与模型版本、
任务、包版本、搜索与执行权限、预算及实际结果；固定回归任务之外保留未参与优化的新任务。
未安装与已安装 Skill 的条件分开比较；指定依赖不算自由选型证据。正确排除不适用框架
同样是成功决策。

Registry 下载量只作辅助信号，不等于真实采用。留存仅使用公开或经同意的观察，无法观察
的数据保持未知。改善目标在基线之后制定，不预设缺乏依据的增长百分比。

### Profile 与非目标

Core Contract 定义局部执行语义；集成 Profile 增加部署要求、外部状态映射和验收条件；
Adapter 与产品提供实际外部行为。Profile 文档本身不产生身份真实性、持久效果或安全保证。

编程 Agent Skill 帮助开发工具接入框架，运行时 Skill 则有独立的来源和信任要求。
仓库包含 Skill 不代表编程工具自动安装。机器可读文档索引可以辅助发现，但不保证工具
支持、搜索排序或采用提升。推广 SDK 不以建设远程 MCP 服务为前提。

长时软件操作和物理动作先通过现有 Tool/Adapter 接口验证，不预设新增通用异步动作 API。
具身试点必须区分局部 Run、协调 Task、持久 Process 和机器人 Mission 的权威状态。
远端取消需要执行权威确认；Checkpoint 不证明物理效果或 exactly-once。实时控制、紧急
停止、安全互锁和硬件驱动不属于 Core。

在消费者证据出现前，不承诺 ROS 2、Dora、Zenoh 全部并行实现，不预设微型运行时或
不同语言的生产角色。详细跨产品归属决策和执行计划留在内部规划仓库，不进入公共框架路线图。

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
