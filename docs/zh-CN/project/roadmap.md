# 公开路线图

当前核心版本为 `2.8.0`。

本路线图按开发者成果组织：判断是否适用、跑出有用结果、完成真实原型、嵌入应用，
最后再加固具体集成。它不是交付排期、产品路线图，也不表示所有语言实现都支持每项能力。

## 下一阶段方向

**规划更新：2026-11-13。** 当前首要目标是缩短从发现框架到做出有用项目的路径。
新用户不需要先理解完整规范、证据分类、跨语言矩阵或高级执行 Profile，才能开始开发。

**规划更新：2026-11-16。** 下一阶段重点是证据深度和第一条可用路径，而不是增加语言
条目。第一条路径是五分钟嵌入，治理验收是第二步。公开声明区分契约完成、Adapter 可用
和集成已验证。默认安全语义也前移：记忆召回默认是不可信数据，除非应用显式提升其权威；
工具参数在编辑后仍重新授权。

PRAXO-CORE 继续定位为**可治理、可嵌入的 Agent 执行框架**。路线图优先完整可运行的
应用路径和清晰集成边界，不追求语言、Adapter、Profile 或测试数量。既有系统和受约束
运行环境是主要集成目标；新增语言 Kernel 或 Adapter 仍需要明确消费者、维护者和真实
部署路径。

### 规划原则

- 先让程序产生有用结果，再解释底层契约。
- 从已发布包和常见本地或托管模型端点开始。
- 首次路径只保留一个最小拒绝检查；完整矩阵和故障演练后移到加固阶段。
- 新能力先使用示例、配方和可选 Adapter，不先扩大 Core 公共 API。
- 只有真实消费者证明可复用缺口后，才增加共享 API。
- 凭据、身份、持久状态、隔离和产品数据始终由嵌入应用负责。

## 语言范围

本路线图适用于整个 PRAXO-CORE 家族，而不只针对 Go 参考实现。Go 定义规范参考行为，
各语言 Core 以独立版本和符合本语言习惯的 API 发布。以下阶段描述共同的开发者路径；
具体语言可用性、安装方式和功能覆盖以[语言实现矩阵](../languages/index.md)和
[支持政策](../languages/support.md)为准。

| 范围 | 语言 | 路线图要求 |
| --- | --- | --- |
| 参考实现 | Go | 定义共享行为并引领参考示例 |
| Agent-capable Core | Python、TypeScript、Java、Rust、R、C# | 共享采用阶段，并在可行时提供可运行的 Provider、Tool 和集成路径 |
| Extended Core | C、PHP、Fortran、COBOL、Ruby、Elixir、Erlang、C++、Lua | 在消费者和维护者需求充分时提供采用路径；高级能力可保持 Go 优先 |
| 其他已声明实现 | 矩阵中的其他语言，以及 Bridge 和 Sample 条目 | 使用对应语言文档并明确差距；不承诺每个示例或功能都可用 |

路线图不要求所有语言同时发布所有示例，但要求面向用户的路径明确标注目标语言和包，
不能把仅在 Go 中成立的行为表述为跨语言保证。语言数量不是目标：`complete` 只表示
契约完成；Adapter 和集成层见[适配器状态](../languages/adapter-status.md)。

## 采用路径

| 阶段 | 开发者成果 | 当前状态 | 下一项成果 |
| --- | --- | --- | --- |
| 0. 判断 | 知道 Core 是否适合，以及该选择哪种语言和路径 | 已有概览、任务入口、对比和非目标说明 | 缩短选型路径，明确应用仍需负责什么 |
| 1. 运行 | 安装发布包、连接模型、注册一个工具并得到有用结果 | 五分钟嵌入路径和确定性 Starter 覆盖主要 SDK；真实模型示例覆盖多种扩展语言；Python、TypeScript、Rust、C#、Elixir、Erlang、Ruby、Lua、Perl、Haskell、PowerShell 和 R 的注册表版本已最新，Java、PHP、Dart、MATLAB、Swift 和 D 仍落后于源码标签（2026-11-15 核对） | 用外部开发者验证五分钟路径，并记录真实端点排错说明 |
| 2. 原型 | 完成一个包含工具、Streaming、结构化输出、MCP、Workspace 或 Telemetry 的连贯本地应用 | 已有示例目录、Workspace 教程、Provider/MCP 演练、本地 MCP 示例、跨语言结构化输出/MCP 教程和 Python/TypeScript/C#/Rust Provider fallback、event-sink 和 streaming 示例；[结构化输出教程](../guides/structured-output-tutorial.md)已覆盖全部三十一种语言 | 增加其余 SDK 的 MCP/fallback 示例和更多语言原型教程 |
| 3. 嵌入 | 将 Core 接入现有服务，由应用管理身份、策略、持久化、事件和退出 | 已有厂商中立的 Go/Python/TypeScript 服务、Go/Python/TypeScript 认证身份/策略服务、TypeScript OIDC/JWKS 验证与 provider discovery、Token introspection/撤销、Go 和 Python 带 provider discovery 的 OIDC/JWKS 验证、Python 可选外部策略决策服务、已验证身份与持久 Checkpoint 变体和分档清单 | 将 Token introspection/撤销和外部身份模式扩展到更多 SDK；增加最小持久 Checkpoint 路径 |
| 4. 加固 | 让具体集成可升级、可失败、可取消、可恢复 | 已有负向、升级、隔离和恢复资产；记忆召回默认作为不可信历史数据，重试测试覆盖未知效果的非幂等风险 | 按应用风险组织，并把恶意跨轮记忆和效果对账用例加入消费者测试模板 |
| 5. 扩展 | 在需要时采用 Plugin、委派、长时操作、Workspace Provider 或具身集成 | 应用级委派示例覆盖 Go、Python、TypeScript、Java、C# 和 Rust；Go 参考示例覆盖长时操作、Workspace 和 Plugin | 在宣称受治理委派前，先实现父子策略、工具范围、预算和深度收窄 |

这些阶段表示推荐采用顺序，不是发布门禁，也不要求所有语言同步推进。

## 阶段 0：判断 Core 是否适合

### 开发者成果

开发者可以在几分钟内回答：

- 嵌入式模型/工具循环是否适合当前任务？
- 应选择哪种语言和 Starter？
- 哪些职责仍由自己的应用承担？

### 立即开始

- [阅读导览](../getting-started/index.md)
- [概览](../getting-started/overview.md)
- [何时不应选择 PRAXO-CORE](../getting-started/when-not-to-use.md)
- [语言实现](../languages/index.md)
- [语言支持与分发](../languages/support.md)
- [框架对比](comparison.md)

### 下一步工作

- 在首页和入门文档中统一一张“任务到路径”表。
- 分开“体验框架”“验证包”和“加固部署”三类路径。
- 用开发者能做成什么描述语言支持，不只展示契约层级和测试覆盖。

[契约与证据状态](contract-status.md)继续保留，但不是第一个项目的前置阅读。

## 阶段 1：跑出有用 Agent

### 开发者成果

从空目录开始，安装已发布包，连接 Ollama 或 OpenAI-compatible 端点，注册一个低风险
工具，并在 15-30 分钟内看到模型响应或工具结果。Quickstart 将五分钟嵌入路径与后续
治理验收路径分开。

首次路径只检查三件事：

1. 应用能够启动；
2. 工具能够成功调用；
3. 一次明确拒绝不产生工具副作用。

它不要求完整治理负向矩阵、跨版本升级套件、Behavior Lab 或兼容性报告。

### 立即开始

- [快速开始](../getting-started/quickstart.md)
- [真实模型 Golden Path](../getting-started/live-model-golden-path.md)
- [Go](../getting-started/consumer-go.md)、
  [Python](../getting-started/consumer-python.md)、
  [TypeScript](../getting-started/consumer-typescript.md)、
  [Java](../getting-started/consumer-java.md) 发布包 Starter
- [Ruby](../getting-started/consumer-ruby.md)、
  [PHP](../getting-started/consumer-php.md)、
  [Elixir](../getting-started/consumer-elixir.md)、
  [Lua](../getting-started/consumer-lua.md) 扩展语言 Starter
- 各语言已提供的 [OpenAI-compatible Adapter](../reference/openai-compatible-adapter.md)

### 下一步工作

- 对 Ollama 和至少一个托管 OpenAI-compatible 端点验证四语言真实模型示例，再扩展到
  其他有维护者的语言。
- 为主要 SDK 提供从确定性 Starter 到真实模型端点的直接后续路径，并给出对应语言的
  安装方式和代码。
- 记录预期输出，以及端点地址、模型名、凭据、超时、Tool Schema 和平台相关环境变量
  的简短排错说明。

## 阶段 2：完成真实原型

### 开发者成果

将首次运行扩展为一个有用的本地应用，例如：

- 结构化输出处理器；
- MCP 工具助手；
- 只读 Workspace 助手；
- 带事件或 OpenTelemetry 输出的 Streaming Agent。

### 立即开始

- [示例目录](../getting-started/examples.md)
- [配方](../guides/recipes.md)
- [集成 Adapter](../integrations/index.md)
- [Plugin 指南](../guides/plugins.md)
- [多 Agent 模式](../guides/multi-agent.md)
- `examples/` 下的 `reference`、`governed-workspace`、`checkpoint`、`plugin` 和
  `recipes` 示例

### 下一步工作

- 扩展 Basic、Integration、Hardening、Advanced 分类的示例目录，并标注发布包/源码模式、
  凭据、本机命令、外部服务和成熟度。
- 为每个主要 SDK 增加一篇连贯原型教程，从现有
  [Workspace 教程](../guides/workspace-agent-tutorial.md)开始。
- 为其余 SDK 增加可运行 MCP 客户端示例；Python、TypeScript 的 stdio 示例和 C#
  的进程内示例已位于对应语言的 `examples/mcp` 目录。
- 统一 Adapter 页面的安装、认证、最小示例和限制说明。

## 阶段 3：嵌入实际应用

### 开发者成果

将 Core 接入现有服务，同时由应用负责：

- 配置和 Provider 凭据；
- 已认证身份和策略决策；
- 明确的工具与资源范围；
- Checkpoint 或应用状态持久化；
- 事件、Telemetry、取消和优雅退出；
- Shell、文件或网络效果周围的隔离。

### 立即开始

- [采用指南](../getting-started/adoption.md)
- [应用嵌入清单](../guides/application-integration-checklist.md)
- [集成指南](../guides/integration.md)
- [身份与策略配方](../guides/identity-policy.md)
- [长时操作配方](../guides/long-running-operations.md)

### 下一步工作

- 为
  [TypeScript OIDC 示例](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/service-auth)
  增加 Token introspection、撤销与 provider discovery，并将外部身份模式扩展到另一种
  SDK。[Go](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth)
  与 [Python](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service-auth)
  示例使用应用局部 HMAC Token；Python 还支持应用拥有的 HTTP 策略决策服务。
- 保持[应用嵌入清单](../guides/application-integration-checklist.md)与只读、有副作用、
  高风险三档一致。
- 在教学型 Checkpoint 示例和高级长时操作 Fixture 之间提供最小持久化路径。

## 阶段 4：加固与维护

完整测试和验证从这一阶段开始成为主要工作。它们用于增强已经存在的应用，不应阻塞
开发者获得第一个有用结果。

### 开发者成果

- 拒绝和依赖故障路径失败关闭；
- 编辑后的最终工具参数重新授权；
- 未知结果不被盲目重试；
- 本地取消不被误认为远端效果已取消；
- Checkpoint 不被当成事务；
- 框架升级后仍保持应用要求的行为。

### 后期工作

- 保持[应用嵌入清单](../guides/application-integration-checklist.md)与只读、有副作用、
  高风险三档一致。
- 扩展[消费者测试模板](../guides/consumer-test-template.md)，增加语言示例，不要求复制
  整个仓库矩阵。
- 将恶意跨轮记忆用例保留在默认套件：记忆内容不能获得指令权威或改变工具授权。
- 保留未知效果重试用例：传输或超时错误不能证明非幂等工具没有产生效果。
- 对真正需要的集成执行升级、故障、负载、Provider、数据库、Collector、Sandbox
  和恢复检查。
- 将 [Execution Correctness](execution-correctness.md)、Behavior Lab、兼容性和
  [验证证据](verification-evidence.md)作为维护与发布质量工作继续推进。

[兼容政策](compatibility-policy.md)和安全修复贯穿所有阶段；后移的只是完整验证。

## 阶段 5：高级与实验集成

高级工作按真实项目需求推进，不按框架完整度分数推进，包括 Plugin、本地委派、MCP/A2A、
Provider-neutral Workspace、远端长时操作和具身集成。

继续使用一个 Kernel 和文档中的[集成层次](../reference/execution-profiles.md)。Governed
与 Embodied Profile 是集成设计，不是独立 Kernel，也不是新用户的必选起点。

AKROVELA 是具身试点选定消费者，PRAXOVELA 是另一个独立产品消费者。具体状态和验收条件
保留在[具身试点计划](embodied-pilot.md)；具身工作不属于普通 SDK 采用主线。

受控委派是下一项高级能力：子 Run 只能收窄父 Run 的策略、工具范围、步数预算和深度，
其最终工具参数仍重新授权。在该契约实现并版本化之前，父子范围收窄仍由应用负责。

没有明确消费者和具体缺口时，不优先增加 ROS、Workspace Provider、新语言或通用异步
Action API。

## 当前优先项

1. 让五分钟嵌入路径真实可用并通过外部验证：发布包、一个模型、一个工具、一次拒绝检查。
2. 获得一个独立消费者、一次第三方复现，以及一条真实 Provider/MCP/Harmovela 集成记录。
3. 先深化现有能力：受控委派范围收窄、记忆来源/信任、最小 Checkpoint/Session Store
   参考实现。
4. 保持三层证据明确：契约完成、Adapter 可用、集成已验证。
5. 发布 MCP、受控委派和 OpenTelemetry trace 的任务型教程，而不是语言数量宣传。

这些优先项选择少量完整路径，而不是更多孤立功能。一个 Go 示例不能证明其他语言 SDK
的开发者路径同样可用，Registry 下载量也不等于采用。

## 采用证据

采用工作分别回答三个问题：开发者能否发现框架、能否完成指定集成、能否在变更后继续
维护。详细方法保留在[采用基线协议](adoption-baseline.md)。

这些实验应在实用路径存在后用于改进文档，不阻塞 Quickstart、示例或集成发布。
有用信号包括首次结果耗时、完成率、修复成本、Issue 质量、完成升级和真实项目中的持续使用。
Registry 下载量本身不等于采用。

## 采用路径稳定后再做

- 仅为增加数量而扩展 Behavior Lab 或兼容矩阵。
- 在没有明确消费者、维护者、真实部署路径和集成证据时，新增语言 Kernel、仓库或大量
  Adapter。
- 在消费者需要崩溃步骤恢复、待处理审批、效果游标或 exactly-once 语义并提供真实恢复
  测试之前，实现 durable execution 模块。
- 每次文档变更后重跑全部历史证据记录。
- 大规模编程 Agent Skill 对比和重复采用实验。
- 为没有活跃消费者的集成补齐全部故障、负载、真实 Provider 和运行证据。
- 在没有维护者和用例时增加语言实现或 Adapter。
- 将具身仿真、硬件或机器人中间件作为通用 SDK 目标。

这些仍是有价值的后期工作，但不是首次开发体验。

## 生态边界

PRAXO-CORE 是可复用 MIT 框架，不是产品平台。PRAXOVELA、AKROVELA、其他 AxisVela
产品和独立应用使用相同公开契约，同时拥有各自的状态、身份、策略服务、工作流、网络、
部署与用户体验。

Core 提供 Model、Tool、Policy、Event、Checkpoint、Plugin、Stream 和 Workspace 接口。
它不运营身份提供商、策略决策服务、工作流引擎、效果账本、网络控制平面或托管 Sandbox。
可选 AxisVela 映射见[生态集成](../integrations/ecosystem.md)。

## 兼容承诺

- 保持 Go 公共 API 精简并维持 MIT 边界。
- 共享 Wire 变更必须显式进入 `spec/`。
- 不仅为简化语言移植或示例而扩大 Go API。
- 允许各语言保持符合本语言习惯的 API；移植不要求镜像 Go 内部实现。
- 在消费者证明可复用 Core 缺口前，优先使用示例和 Adapter。
- 保留已发布 URL，并为破坏性变更提供迁移指南。

参见[兼容政策](compatibility-policy.md)、[Core 支持](../languages/support.md)和
[语言规范](../contributing/language-policy.md)。

## 状态与已交付内容

路线图说明方向，详细状态与验证保留在：

- [契约与证据状态](contract-status.md)
- [版本历史](../releases/index.md)
- [验证证据](verification-evidence.md)
- [完整变更日志](https://github.com/axisvela/praxo-core/blob/main/CHANGELOG.md)
