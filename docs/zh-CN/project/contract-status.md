# 契约与证据状态

**状态：** 公开规划参考，2026-11-22。本页定义路线图使用的状态词，并记录主要契约领域的
当前状态。它不是发布排期，也不扩大任何 API 或 Profile。

## 状态词

| 状态 | 含义 | 最低证据 |
| --- | --- | --- |
| 已实现（Implemented） | 规范契约或公开 API 已在 Go 参考实现中存在并有自动测试 | 源码、适用时的 API 快照和测试 |
| 已验证（Verified） | 证据绑定到精确提交、产物和日期 | 该 revision 的运行或评审记录 |
| 提案（Proposed） | 仅设计或验收标准 | 设计文档；没有 API、Wire 或 Profile 保证 |
| 实验（Experimental） | 已有明确消费者可用，但可能变化，不在稳定承诺内 | 消费者和写明限制的测试 |
| 未运行 / 未开始（Not run / Not started） | 尚无结果或实现证据 | 无；不得写成通过 |

`已验证` 是限定范围的证据。后续仅文档提交不会扩展它。集成测试不证明采用，一致性测试
不证明生产安全或运行就绪。

这些词描述契约与证据状态，不替代 [`spec/parity.md`](https://github.com/axisvela/praxo-core/blob/main/spec/parity.md)
中的 `planned`、`partial`、`parity`、`n/a` 覆盖标签，也不替代[语言总表](../languages/matrix.md)
中的支持等级。

## 当前矩阵

| 领域 | 状态 | 范围与限制 |
| --- | --- | --- |
| Standard Embedding | 已实现；按标注 API/包 revision 验证 | 现有可配置嵌入方式；允许 nil Policy 与空/不限工具范围；不是安全认证 |
| Execution Correctness Suite | 清单提案；已实现 EC-D 局部机制 runner；完整套件未运行 | EC-01 至 EC-14，EC-D/EC-I/EC-O 分轨；runner 覆盖 EC-01/03/04/06/08/10/14 的局部机制（EC-14 仅为恢复顺序）以及独立的 EC-11 本地 containment scope，不是完整套件或 Profile 通过 |
| Go 参考 API 与共享 Wire 产物（事件、错误、JSON Schema 子集、插件） | 已实现；按发布 revision 验证 | `spec/` 中的规范文件与向量；不证明真实 provider 或产品部署 |
| Tool、Model、Checkpoint Wire 描述 | 已实现；`SPEC_VERSION` 0.2.0 的描述性文件 | 共享 Tool/Model 形状与 Checkpoint allowlist envelope 属于 Wire；Go checkpoint 与解析后 tool-call 投影标记为 `"wire": false`，不是冻结的跨语言契约 |
| Go、Python、TypeScript、Java 独立消费者 | 已实现；在各自标注 revision 验证 | 发布包安装、构建与确定性允许/拒绝检查；属于集成证据，不是采用证据 |
| Ruby、PHP、Elixir、Lua 独立消费者 | 已实现；四个源码模式本地检查通过；RubyGems、Hex、LuaRocks、Composer 的已发布版本安装均本地通过，PHP `0.4.1` Starter 无需 autoload 桥接 | 发布包安装、构建与确定性允许/拒绝检查；扩展语言 Starter，不属于四语言治理试点 |
| Python 发布包升级 | 已实现；由 CI 验证 | 安装 PyPI `0.2.4`，将不变消费者升级到 `0.3.0`，并重跑治理兼容检查；仅一个版本对，不是通用升级保证 |
| TypeScript 发布包升级 | 已实现；由 CI 验证 | 安装 npm `0.1.5`，将不变消费者升级到 `0.2.0`，并重跑 starter/治理检查；仅一个版本对，不是通用升级保证 |
| Java 发布包升级 | 已实现；由 CI 验证 | 解析 Maven Central `0.3.0`，将不变消费者升级到 `0.4.0`，并重跑 starter/治理检查；仅一个版本对，不是通用升级保证 |
| Go、Python、TypeScript 与 Java 治理负向验收 | 已实现；在各自标注 revision 验证 | 各五项应用层检查：缺少 Policy/范围、最终参数与审批编辑重授权、Policy 服务失败；不是通用 Profile |
| Go 身份/策略配方 | 已实现；在标注 revision 验证 | 应用提供已验证 principal；缺失、过期、租户不匹配与模型伪造角色均拒绝；不是身份提供商或 PDP |
| Go 记忆召回角色 | 已在 Go `2.9.0` 实现并发布；修复最初记录于 `73da5139`；2026-11-16 本地确定性检查 | Go 将召回作为带 frame/source 标签的 user 数据，而非 system 消息；assistant 写入记录带 `source`、`trust` 元数据。测试检查消息角色和拒绝零效果，不证明通用提示注入防护。`2.9.0` 包含该修复；`2.8.0` 仍使用 system 召回。源码审计未发现其他 SDK Agent 主路径的自动召回，Memory Store API 属于独立能力；对 Bridge `run` 与 `event stream` 路径的源码审计未发现记忆构造、召回注入或 system 角色提升，也没有端到端 Bridge 记忆测试；不声称跨语言修复 |
| 认证服务身份示例 | 31 个已声明实现中有 30 个提供源码级 introspection/revocation 模块。已在本地用脚本化、loopback 或文件重定向 transport 验证：Go、Python、TypeScript、C#、Ruby、PHP、Dart、Elixir、Erlang、Perl、Rust、Lua、D、C、C++、Objective-C、Delphi/FPC、Zig、Fortran、PowerShell、Java、Swift、Haskell、OCaml、Julia、Nim、V 和 R。GNU Octave 运行 MATLAB/Octave 共享认证测试；原生 MATLAB 因未安装仍未验证。COBOL 仅记录 transport 边界。 | Go、Python 和 TypeScript 默认验证应用局部 HMAC Token，配置后验证带 Provider 发现的 OIDC/JWKS JWT；C# 在设置 `PRAXO_OIDC_ISSUER` 与 `PRAXO_OIDC_AUDIENCE` 后验证带 Provider 发现的 OIDC/JWKS JWT。Introspection 模块要求 `active: true`、非空 `sub` 与 tenant claim、未来整数 `exp`；OIDC/JWKS 模块要求匹配的 issuer 与 audience，以及非空 subject 与 tenant claim。撤销失败关闭。Handler-only 示例使用调用方提供的 transport；Java、C#、Swift 包含标准客户端 transport。除 Go、Python、TypeScript 与 C# 外不包含 OIDC/JWKS。测试使用 loopback 或脚本化 transport；不是身份提供商、密钥管理器或生产撤销服务 |
| Go 长时操作配方 | 已实现；在标注 revision 验证 | L4 配方证据：文件（temp+sync+rename）、loopback HTTP、子进程重启、独立 verifier 进程与文件 fencing fixture 覆盖幂等提交、响应丢失、部分写入恢复、rename 前后确定性故障注入、损坏状态失败关闭、取消请求/确认、Run 取消、完成/效果验证区分、verifier 收据、持久 fencing、lease 过期/续期/撤销、带 health/readiness、基础 metrics、示例 Prometheus scrape/留存/告警配置（仅配置校验；无 live collector）、环境变量配置、file-based token/secret 轮换（签发属外部）与优雅退出的独立服务二进制、可配置 file/SQLite/Postgres lease 后端与 reload-modify-save（SQLite 已验证；Postgres gated 测试需 `PRAXO_POSTGRES_DSN`，本环境未验证）、rename 边界前后进程级崩溃、gated 100 提交负载/故障测试与干净检出复现脚本、使用自己 token/密钥的独立 verifier 二进制，以及静态 Bearer/TLS 拒绝；只有 Run 取消断言触及 Core 接缝。无生产密钥管理、lease 协调服务、可信时钟、OS 级断电证明、身份提供商或 exactly-once；未配置 lease 时，边界测试记录并发写入者的丢更新 |
| Go 适配器一致性配方 | 已实现；在标注 revision 验证 | 使用 `pkg/conformance` 校验 fake model、流式 model、tool 与 retriever 契约，包括不匹配失败；不是 live provider 或生产证据 |
| Go 重试安全配方 | 已实现；在标注 revision 验证 | 演示 `tool.Retry` 谓词、取消、非幂等重复效果风险，以及带状态查询的应用侧 wrapper；不提供 Core effect ledger 或 exactly-once 保证 |
| Go 事件 sink 配方 | 已实现；在标注 revision 验证 | 演示 `MultiSink`、`FilterSink`、`PublisherSink`、工具调用前 sink 失败阻断，以及终态 sink 失败不掩盖原始错误；不证明持久确认或生产遥测 |
| Go 上下文预算配方 | 已实现；在标注 revision 验证 | 演示确定性压缩、System 消息保留、超大 System 失败关闭、summary 压缩与摘要模型失败回退；不是通用 prompt-injection 过滤器或来源认证 |
| Go checkpoint 存储配方 | 已实现；在标注 revision 验证 | 实现 `checkpoint.Store` 的 temp-file + sync + rename、重开恢复、部分临时文件容忍、租户范围加载与删除；教学存储，不是并发数据库或 exactly-once 证明 |
| Go 结构化输出配方 | 已实现；在标注 revision 验证 | 使用 `pkg/tool/jsonschema` 子集校验结构化输出与工具参数，在工具效果前拒绝非法值，并把 schema 放入 `ResponseFormat`；不保证 provider 支持结构化输出或完整 JSON Schema |
| Go VFS containment 配方 | 已实现；在标注 revision 验证 | 演示 rooted `localfs`、traversal/NUL/根删除拒绝、宿主支持 symlink 时的逃逸拒绝、只读路径授权与空授权 deny-by-default；属于本地宿主控制，不是容器/VM 隔离 |
| Go provider fallback 配方 | 已实现；在标注 revision 验证 | 演示主模型选择、带谓词的回退、双失败行为、取消时不回退、空主模型回退；不是 provider SLA 或故障转移服务 |
| Go plugin lifecycle 配方 | 已实现；在标注 revision 验证 | 演示仅 ACTIVE 接受 Acquire、受保护状态转换、带超时/取消区分的 in-flight drain、Revoke 到 UNLOADED、终态 Quarantine；不是进程/WASM 隔离或 manifest 信任证据 |
| Go multi-agent 配方 | 已实现；在标注 revision 验证 | 演示 launch/完成/失败/取消、运行中更新门禁、按父 session 列出、仅清理终态任务、Wait 取消；属于本地任务协调，不是持久远程 worker |
| Go streaming 配方 | 已实现；在标注 revision 验证 | 演示有序 `OnDelta` 片段、完整最终响应、流错误传播、取消与 typed `OnStream` 投影；不保证 live provider 或工具增量聚合 |
| Workspace session 契约示例 | 评估中；使用 fake provider 离线验证 | 运行共享的 create/attach/upload/download/VFS/命令/close/可选 Pauser 一致性检查，并校验 `state`/`local`/`sandbox` 运行时 profile 的信任、隔离、能力与工具选择规则；不属于 `pkg/`，无 live provider，无隔离证据 |
| Governed Execution Profile | 提案；已有部分集成证据 | G1-G8 验收清单与消费者统一装配设计；结构化配置和依赖校验，不是已实现总开关或 Core 新 API；实际约束分层执行，配置成功不等于行为验收 |
| 编程 Agent 集成映射 | 已实现；版本由文档测试校验 | 包映射、集成契约与验证命令；不是安装渠道、自动 Skill 或采用证据 |
| 编程 Agent 发现辅助 | 已实现；`llms.txt` 存在且链接由测试校验 | 机器可读仓库入口；不保证工具发现、搜索排序、安装或采用 |
| 编程 Agent Skill 模板 | 实验；两项有范围的工具结果 | 工具中立的 `SKILL.md`。Claude Code `2.1.196` 于 2026-11-08（`bdd36d7`）在临时 home 中安装并列出 Skill 组件；该 CLI 未登录，因此未执行任务。opencode `1.18.18` 发现了项目本地副本，并用已发布 PyPI `praxo-core==0.3.2`、显式工具范围和 allow/deny 测试完成确定性 Python 任务（3/3 通过；模型 `deepseek/deepseek-flash`；2026-11-08，`7004a08`）。Codex、Copilot、自动安装、MCP 与运行时 Skill 行为仍未验证 |
| Registry 页面元数据 | 版本已发布；新版本的渲染页面复审待完成 | 当前 registry 版本与地址只记录在 [Registry 发布状态](../languages/registry-status.md)。Go `v2.10.0` 是当前发布版本；尚未记录其 pkg.go.dev 页面核对结果。最新发布后尚未逐页复审渲染后的 README 与包页面。 |
| 每语言 Registry 与编程 Agent 入口 | 已实现；生成并由链接测试校验 | 每个 `language/<language>/` 目录都有 `REGISTRY.md`、`llms.txt` 与 `llms.md`，并提供中央索引和 README 链接。npm、Python sdist、Cargo、NuGet、RubyGems、Hex、CPAN 与 Hackage 的允许清单已包含这些文件；Maven Central 仍以 POM 元数据为主。这是源码证据，不证明 Registry 页面已刷新 |
| 编程 Agent 采用实验 | 已运行试点；完整基线未运行 | [采用基线协议](adoption-baseline.md)定义轨道、任务、指标与证据。一次 opencode `1.18.18` 与 `deepseek/deepseek-flash` 试点记录：指定集成在有无 Skill 时各通过一次；自由选型无 Skill 时 3/3 次未发现 PRAXO-CORE，有 Skill 时 3/3 次选择它；原不适用 workflow 任务超时且未计分，受限后续任务 3/3 次推荐非 Core workflow/sandbox 组合，并在有 Skill 时 3/3 次明确排除 PRAXO-CORE。预注册的 held-out 任务一次超时、每种条件三次完成：两种条件在全部完成试验中都选择 PRAXO-CORE，与无 Skill 时 3/3 regression 未发现的结果不一致；有 Skill 时一次试验需要一次修复。一次受限升级试点在源码不变的情况下安装 0.3.2 并通过 8/8 测试；后续任务将 `requirements.txt` 更新为 0.3.2，源码不变且 8/8 测试通过。后续变更后的留存仍未观察；不是采用证据 |
| Embodied Integration Profile | 设计提案；AKROVELA P1/F5 与 E1-E8 确定性/本地组件矩阵已通过；P2/P3 未运行 | 治理之上增加远程动作、绑定/新鲜观测、取消确认和效果验证；分开实验证据、Mission 权威、运行世界状态、独立保障与本地安全；AKROVELA 像 PRAXOVELA 一样嵌入 Core；产品侧适配器、确定性 P1 切片、F5 本地 process/API 仿真（模拟观测源与 bridge 后端）以及 bridge/verifier 持久状态快照已存在于 AKROVELA 仓库。产品 E1-E8 确定性/本地组件矩阵在 `f8fd4d7` 通过；这不是 P2 验收。真实 ROS 2/Gazebo/Linux 执行、独立观测/验证者、硬件效果、PEIRAVELA 与 E1-E8 试点验收仍待定 |
| 具身试点计划 | 提案；2026-11-22 修订；AKROVELA P1/F5 与 E1-E8 确定性/本地组件矩阵已通过，Core `v2.10.0` 升级已合并 | 复用治理装配，以 G1-G8 加 E1-E8 和允许端到端路径验收。AKROVELA 已选定为消费者并明确维护者和安全负责人；产品适配器、精确操作工具、治理运行时装配、PostgreSQL 日志、公开 v1 操作/回执契约、F5 adapter/API 仿真范围、模拟 verifier 源、带 `simulated` 与 `rclpy` 后端的 ROS 2 bridge，以及 bridge/verifier 持久状态快照已存在于 AKROVELA 仓库。E1-E8 确定性/本地组件矩阵在 `f8fd4d7` 通过；真实 ROS 2/Gazebo/Linux 执行、独立观测源/验证者、硬件效果、PEIRAVELA 与 E1-E8 试点验收仍待定；产品未记录已接受的 P2 试点运行 |
| AKROVELA / DIDACTOVELA 集成 | AKROVELA 0.13.0 组件发布；P1/F5 与 E1-E8 确定性/本地组件证据；Core `v2.10.0` 升级已合并；DIDACTOVELA 提案 | AKROVELA 像 PRAXOVELA 一样通过产品侧适配器嵌入 PRAXO-CORE；现已有精确操作工具、治理运行时装配、PostgreSQL Run/对账日志、公开 v1 操作/回执与卫星命令契约、F5 本地组件/adapter 证据，以及 E1-E8 确定性/本地组件矩阵，并已在本地验证。DIDACTOVELA 仍为可选学习边界。AKROVELA 为 0.13.0 组件发布，嵌入 PRAXO-CORE `v2.10.0`；DIDACTOVELA 仍为未发布 0.1.0 产品。尚无真实 ROS 2/Gazebo/Linux 执行、硬件效果、独立观测/验证者、live KINETOVELA 集成、PEIRAVELA 运行或 E1-E8 试点验收 |
| 语言一致性、功能覆盖与运行证据 | 参见 `spec/parity.md`、语言总表与 Behavior Lab | 分开的维度；源码标签不提供运行证据 |

## 引用证据

引用状态时写明 revision、产物和结果，并说明证据属于哪一层：

1. 契约一致性；
2. 已发布包消费者检查；
3. 真实本地服务或 provider 集成；
4. 硬件、仿真或生产观察。

不得用一层暗示另一层。L1-L6 与 consumer/长时操作测试的映射见
[测试与证据分层](test-taxonomy.md)。特别是长时操作套件属于 L4 应用配方证据，不是
Core 能力声明。

采用实验中明确指定框架属于指定集成证据，不是自由选型证据。正确排除不适用框架是成功的
选型决策，不是采用失败。

共享 Wire 变更分类见 [`spec/README.md`](https://github.com/axisvela/praxo-core/blob/main/spec/README.md)
规范规则与[兼容政策](compatibility-policy.md)。可选 Profile 不能绕过 Wire、parity 或
conformance 审查。
