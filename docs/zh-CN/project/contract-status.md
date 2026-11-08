# 契约与证据状态

**状态：** 公开规划参考，2026-11-08。本页定义路线图使用的状态词，并记录主要契约领域的
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
| Python 发布包升级 | 已实现；由 CI 验证 | 安装 PyPI `0.2.4`，将不变消费者升级到 `0.3.0`，并重跑治理兼容检查；仅一个版本对，不是通用升级保证 |
| TypeScript 发布包升级 | 已实现；由 CI 验证 | 安装 npm `0.1.5`，将不变消费者升级到 `0.2.0`，并重跑 starter/治理检查；仅一个版本对，不是通用升级保证 |
| Java 发布包升级 | 已实现；由 CI 验证 | 解析 Maven Central `0.3.0`，将不变消费者升级到 `0.4.0`，并重跑 starter/治理检查；仅一个版本对，不是通用升级保证 |
| Go、Python、TypeScript 与 Java 治理负向验收 | 已实现；在各自标注 revision 验证 | 各五项应用层检查：缺少 Policy/范围、最终参数与审批编辑重授权、Policy 服务失败；不是通用 Profile |
| Go 身份/策略配方 | 已实现；在标注 revision 验证 | 应用提供已验证 principal；缺失、过期、租户不匹配与模型伪造角色均拒绝；不是身份提供商或 PDP |
| Go 长时操作配方 | 已实现；在标注 revision 验证 | L4 配方证据：文件（temp+sync+rename）、loopback HTTP、子进程重启、独立 verifier 进程与文件 fencing fixture 覆盖幂等提交、响应丢失、部分写入恢复、取消请求/确认、Run 取消、完成/效果验证区分、verifier 收据、持久 fencing 与静态 Bearer/TLS 拒绝；只有 Run 取消断言触及 Core 接缝。无生产密钥管理、lease 过期/撤销、断电证明、身份提供商、锁或 exactly-once |
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
| 编程 Agent Skill 模板 | 实验；仅仓库模板 | 工具中立的 `SKILL.md`；安装与发现未验证，不声明自动安装、MCP 或运行时 Skill 行为 |
| Registry 页面元数据 | 源元数据已更新；已发布页面尚未更新 | 2026-11-05 审计 PyPI、npm、Maven、Go 页面；页面只随新版本更新；其他 Registry 发布时检查 |
| 编程 Agent 采用实验 | 未运行 | 没有发现、选型、首次通过、修复成本或留存数据 |
| Embodied Integration Profile | 设计提案；消费者试点未开始 | 治理之上增加远程动作、绑定/新鲜观测、取消确认和效果验证；分开实验证据、Mission 权威、运行世界状态、独立保障与本地安全；复用已发布契约，必需能力不可用时阻塞验收 |
| 具身试点计划 | 提案；2026-11-08 修订 | 复用治理装配，以 G1-G8 加 E1-E8 和允许端到端路径验收；拟交付消费者示例、实验适配器与消费者局部协议，不新增共享 API/Wire；未选定消费者、中间件、仿真、执行权威、观测源、验证者或安全负责人，没有运行记录 |
| AKROVELA / DIDACTOVELA 集成 | 提案；未运行 | 可选现场执行与学习生命周期边界；两产品均为未发布 0.1.0 运维骨架，不是 Core 适配器、领域协议或已验证集成 |
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
