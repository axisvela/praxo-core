# Execution Correctness Suite

**状态：2026-11-06，验收清单提案，并已实现本地 EC-D scope runner。** 本文定义
Execution Correctness Suite（EC）；runner 只覆盖声明的局部机制范围，完整 EC 清单仍为
计划/not-run。已有测试须复核断言后复用，不能由本文重新认证。

## 目标

在 [Behavior Lab](../languages/behavior-lab.md)之外，验证自主执行的失败边界，不向所有语言
复制二十个常规场景，也不为增加覆盖数扩大 API。先针对 Go 参考实现与明确消费者集成；
语言扩展按实际消费者需求和共享 spec/parity 流程进行。

通过[Standard Embedding 与执行 Profile](../reference/execution-profiles.md)声明被测集成范围。
[Governed Effect Boundary](../reference/governed-execution.md#governed-effect-boundary)划分意图、
授权、执行、效果确认与对账的执行责任；EC 测试不会把这些责任转移给 Core。

## 验证轨道

EC 使用轨道名，不重新定义已有 L1-L6 [测试分类](test-taxonomy.md)。

| EC 轨道 | 验证对象与实施位置 | 现有证据分类 |
| --- | --- | --- |
| EC-D Deterministic | PRAXO-CORE 所有的状态机、授权、回调、取消、错误和结果传播 | L1；另行执行 SDK 一致性才是 L2；应用 fake 仍是 L4 |
| EC-I Integration | 消费者/产品集成测试中的真实数据库、网关、Effect Ledger、Sandbox | 应用配方为 L4；真实服务证据按实际范围分类，不由轨道名自动升级 |
| EC-O Operational | 产品部署与独立验证中的进程崩溃、网络分区、并发负载、多租户和真实设备 | 具备真实运行证据才属于 L6；模拟故障本身不是生产证据 |

EC-D 通过不代表 EC-I 通过，EC-I 通过也不满足 EC-O。同一场景可以在多个轨道分别记录结果。
SDK 或发布包执行可另外提供 L2/L3 证据，但不会提升外部效果或部署声明。
独立验证可由 TEKMOVELA 或其他合格验证系统承担；不要求使用 AxisVela 产品。
PRAXOVELA 效果台账与 RHEOVELA 工作流测试可承担产品侧 EC-I，不代表这些实现需要迁入 Core。

## 场景清单

下表的 Outcome、Unknown、Accepted、Physical Commit 是语义描述，不是新增 Core 类型、
事件名、错误码或共享 Wire 状态机。

| ID | 失败场景 | 必须满足的验收条件 | 所有权与轨道 |
| --- | --- | --- | --- |
| EC-01 | 并行工具之一失败，其他调用已提交 | 每个已尝试调用均可确认或明确未知；批次错误不得暗示无效果 | Core 回调/结果传播 EC-D；外部结果台账与验证 EC-I/O |
| EC-02 | 工具提交后响应丢失 | 在可能产生未确认重复效果的重试前核实权威状态 | 消费者/工具权威 EC-I/O；确定性协议 fixture 仅是模型 |
| EC-03 | 非幂等操作遇到 Tool Retry | 阻止无保护自动重试；需证明无效果或目标端幂等/状态解析 | Core retry 机制 EC-D；受保护配置与 Effect PEP EC-I/O |
| EC-04 | 审批后参数改变 | 原审批不能授权变更后的最终操作；绑定最终参数及审批有效期/使用语义 | Core 最终授权 EC-D；持久审批与 Effect PEP EC-I/O |
| EC-05 | 工具等待期间撤销授权 | 最终执行/提交边界拒绝，或按目标协议确认终止；不从局部检查承诺立即停止 | Core 复核接缝 EC-D；实际执行权威 EC-I/O |
| EC-06 | Context 压缩超过预算 | 保留必需指令或明确失败，不为满足预算而静默丢弃 | Core 上下文装配/压缩 EC-D；消费者准入策略 EC-I |
| EC-07 | 不可信 Memory 含伪造指令 | 不因装配/恢复取得更高指令权威或权限 | Core 上下文处理 EC-D；来源认证与集成策略 EC-I/O |
| EC-08 | Agent 取消但外部任务继续 | 未获权威确认，不得宣称外部效果已停止 | Core 局部取消 EC-D；远程取消/状态协议 EC-I/O |
| EC-09 | Effect 提交后 Checkpoint 尚未保存 | 恢复在重做效果前查询权威业务状态 | 消费者效果/Checkpoint 集成 EC-I/O；fixture 不使 Checkpoint 成为事务 |
| EC-10 | Event Sink 故障 | 缺少必需确认时不得声称证据持久保存；区分效果前门禁与提交后补证 | Core 配置回调/错误行为 EC-D；持久确认与存储 EC-I/O |
| EC-11 | Sandbox API 一致但隔离不足 | 不由 API 一致性提升为已验证隔离；声明未支持控制和平台限制 | Core 适配契约 EC-D；真实隔离 EC-I/O |
| EC-12 | 多 Agent 并发改同一资源 | 资源版本、并发控制或 fencing 拒绝过期/冲突效果 | 消费者资源权威 EC-I/O；Core fake 不实现分布式锁 |
| EC-13 | 机器人接受任务但未完成 | Accepted 不等于 Physical Commit，完成与观测效果需分别证明 | 具身消费者仿真 EC-I；真实设备/部署 EC-O |
| EC-14 | 中断后重复恢复 | 保持逻辑操作身份，避免非预期重复效果；未知状态需对账 | Core 恢复/取消接缝 EC-D；消费者持久操作权威 EC-I/O |

## 可复用证据候选

[已审计清单](https://github.com/axisvela/praxo-core/blob/main/scripts/execution_correctness_inventory.json)
将十四个 ID 分配到局部断言候选或明确的外部/缺口处置。首批 `core-mechanics-baseline` 只选
EC-01/03/04/06/08/10 的局部机制；EC-01 仅覆盖本地结果通知，外部效果确认仍属外部。
它不是 runner 或运行报告；完整场景验收字段仍为 not-run。结构测试只检查映射的函数存在，
不证明执行满足 EC 场景。

以下只是候选，不是完整 EC 通过矩阵。分配结果前需审查断言、revision、环境与负向场景。

| 候选 | 潜在覆盖 | 尚未证明 |
| --- | --- | --- |
| `pkg/agent/tool_authorization_test.go` | EC-04 最终操作局部检查 | 持久审批消费/过期与实际目标执行 |
| `pkg/agent/tool_cancel_test.go`、`completion_cancel_test.go` | EC-08 局部取消 | 远程停止确认 |
| `pkg/agent/context/` 与上下文集成测试 | EC-06/07 局部规则 | 真实来源链或通用 Prompt Injection 防护 |
| `examples/governed-workspace` | EC-04/05/07 应用级审批、调用复核与来源包装 | 可选 L4 模式；不是 Core 默认、产品强制入口、真实 PEP 或来源认证器 |
| `examples/recipes/long-running-go` | EC-02/08/09/12/14 应用 fixture | 已部署服务、生产 lease、网络分区和断电证明 |
| Sandbox/host 测试及平台限制 | EC-11 契约和选定隔离检查 | 整体部署隔离或认证 |

当前 `tool.Retry` 零值只执行一次，配置多次尝试不会自动判断效果安全；缺失 ShouldRetry
不意味着目标具有幂等。EC-03 是验收要求，不声明 Core 已实现非幂等保护。

同样 `event.Sink.Emit` 成功不单独证明持久保存。EC-10 必须明确 sink 确认含义及必需证据失败
处理策略；效果后的错误不能证明无效果。

## 记录与验收

遵循[测试证据规范](../contributing/test-evidence.md)。每个场景/轨道记录必需范围、Profile/设计
revision、准确包/依赖版本与 SHA、故障点、初始状态、逻辑操作键、权威验证查询、预期/实际效果数
与证据确认、命令输出、结果和工件引用。

分别统计 passed、failed、skipped、blocked、not-run，保留每次尝试及最初失败。缺少必需轨道或
故障断言时验收不满足，不能把缺失集成/运行证据记为通过。可选排除必须有理由并收窄声明。
文档清单检查不能变成执行结果。

## EC-D Scope Runner

本地机制 runner 位于
[`scripts/execution_correctness.py`](https://github.com/axisvela/praxo-core/blob/main/scripts/execution_correctness.py)，
读取审计清单和 `core-mechanics-baseline` scope，仅按名称运行父测试，使用
`go test -json -count=1` 与 `GOWORK=off`。

```bash
python scripts/execution_correctness.py --strict
```

默认严格；`--advisory` 仍写报告但 scope 失败返回成功。`--go` 选择工具链，`--timeout`
设置 Go 超时，`--output` 改报告根目录。每项父测试/子测试必须有精确终态 `pass`；缺失、
skip、fail、blocked、超时、冲突或损坏 JSON 均不算通过。报告记录 inventory 哈希、设计
revision、命令、退出码、原始 JSON 事件、stdout/stderr 与选中结果。

每次运行写入 `build/execution-correctness/<run-id>/`，含 `report.json`、`report.md`、原始
事件和日志；`latest.json` 只是便利指针，旧目录不覆盖。状态为 `scope-passed`、
`scope-failed` 或 `invalid`，不表示完整 EC 或 Profile 通过。首批仅覆盖 EC-01/03/04/06/08/10
的局部机制；EC-01 仅为通知，EC-02、EC-05、EC-07、EC-09、EC-11 至 EC-14、EC-I、EC-O 及所有
Profile 验收仍未运行或属外部。

## Roadmap 顺序

1. 将已有确定性断言映射 EC ID，明确缺口，不复制测试或为填表虚构效果 metadata。
2. 实现有边界的 EC-D runner/报告，补错误/未知传播、retry 配置、授权和上下文边界回归；
   不暗示 Core 验证了外部效果。
3. 增加明确消费者的 EC-I：数据库、效果/审批执行、真实隔离与恢复；先复用 Hook，再评估 API。
4. 消费者承担 EC-O 故障、负载与部署验证；满足前置条件后进行具身仿真，硬件与生产观察分开。

以上为计划工作，不是已完成里程碑。共享安全/效果契约变化仍需兼容性、规范 spec、向量、parity
和 SDK 影响评审。本设计不增加 Profile API 或改变默认行为。
