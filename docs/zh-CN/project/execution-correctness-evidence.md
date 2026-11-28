# 执行正确性证据索引

本页是 PRAXO-CORE 及其命名消费者中执行正确性检查的公开索引。它不表示
EC-01 至 EC-14、某个 Profile 或生产部署已经通过。

EC 契约定义在 [execution-correctness.md](execution-correctness.md)。检查有意分散：
Core 负责本地机制，产品仓库负责数据库、效果、sandbox、部署和消费者证据。原始
日志和内部运行记录保留在所属产品仓库或私有规划存储中。

## 相关页面

- [执行正确性](execution-correctness.md)：定义模型与要求。
- [验证证据](verification-evidence.md)：更广泛的运行证据。
- [契约状态](contract-status.md)：汇总当前实现状态。

## 快照

| 项目 | 结果 |
| --- | --- |
| EC-D 本地范围 | `27/27` 个选定 selector，`scope-passed`（`scripts/execution/execution_correctness.py --strict`） |
| EC-D containment 范围 | `5/5` 个选定 selector，`scope-passed`（`--scope core-containment-baseline`） |
| EC-D 报告 | `build/execution-correctness/20261108T060739Z-46018b60/`（机制）和 `build/execution-correctness/20261108T060739Z-4942cb69/`（containment）（本地、可复现、未提交） |
| Core revision | 本快照使用的工作区为干净状态 `384ac48` |
| 完整 EC-01..EC-14 验收 | **未运行**；本索引是范围/证据映射，不是验收 |
| EC-I / EC-O | 仅部分本地检查；没有已部署 authority 或独立 AEP |
| Boundary 测试 | 单独记录在 inventory 中；不是验收 selector，也不计入 EC-D 范围通过数 |

## 完整 EC 映射

`Core` 指 `praxo-core`。产品行是由对应产品拥有的证据，不计入 EC-D 范围。

| EC | Core / EC-D 证据 | 产品 / EC-I 证据 | 证据能证明什么 | 状态 / 剩余工作 |
| --- | --- | --- | --- | --- |
| EC-01 | `pkg/agent/parallel_outcome_test.go::TestParallelToolFailureStillReportsEveryOutcome`；EC-01 修复 `65793fd` | PRAXOVELA tool/effect ledger 测试 | batch 出错后仍报告每个已尝试 tool outcome；返回第一个错误 | 仅本地通知；外部效果确认/未知分类仍由消费者负责 |
| EC-02 | 无 Core effect-authority 声明 | RHEOVELA：Postgres effect store、HTTP list/reconcile、8-way reconcile、compensation effect、A/B/C 边界；RHEOVELA `d477e35` 和 `4121001`：outbox 将丢失响应记录为 `unknown`，手动补偿执行已声明能力，PostgreSQL effect begin 通过 `ON CONFLICT` 幂等；PRAXOVELA：持久 `effect_jobs` outbox + replay，`9998c75` 记录未知 tool outcome 并阻止盲目重试；demo C9 | 真实本地 PostgreSQL 和 SQLite lost-response fixture 产生 unknown effect、进行 reconcile、不重新调用 provider；PRAXOVELA outbox 覆盖相同 unknown/no-retry 路径 | **部分**；没有真实外部 provider post-commit/status 查询 |
| EC-03 | `pkg/tool/retry_test.go`（`TestRetryMiddlewareHonorsShouldRetry`、`TestRetryMiddlewareZeroValueDoesNotRetry`、`TestRetryMiddlewareStopsOnContextCancellation`） | RHEOVELA/PRAXOVELA 幂等测试 | 重试次数/predicate/cancel 行为；本地幂等 | 没有非幂等 target 保护或 provider 侧幂等证明 |
| EC-04 | `pkg/agent/tool_authorization_test.go` 最终参数/name 重授权测试 | PRAXOVELA 受治理启动、tool scope 和 CopilotKit gate | 最终 arguments/name 会重授权；产品入口拒绝不安全默认值 | 持久审批绑定、过期、消费和 replay 仍属产品/EC-I |
| EC-05 | `pkg/agent/ec_boundary_test.go::TestEC05UnchangedFinalArgumentsSkipSecondAuthorization` 记录边界：未变化最终参数不再重授权 | PRAXOVELA P0 入口 policy/边界接线 | Core seam 不对未变化最终参数再次调用 Policy；commit 时撤销不是 Core 保证 | 实际 PEP commit/revocation 和确认停止仍为外部 |
| EC-06 | `pkg/agent` context-budget/compaction 测试 | PRAXOVELA adapter/config 测试 | 必需 context/budget 失败会 fail closed | 消费者准入规则和源数据仍为外部 |
| EC-07 | `pkg/agent/context/ec_boundary_test.go::TestEC07CompactionKeepsFirstSystemRegardlessOfSource` 和 `TestEC07ToolResultNotPromotedToSystem` 记录本地边界 | PRAXOVELA context/trust 测试 | 第一条 System 消息无论来源都优先，tool output 保持 Tool 消息；Core 不认证来源 | 来源认证和真实权限执行仍为外部 |
| EC-08 | `pkg/agent` cancellation 测试（`TestRunStopsStartingToolsAfterCancellation`） | PRAXOVELA cancellation/run 测试 | 本地 cancel 阻止后续本地 tool 启动 | 远程任务状态/停止确认仍为外部 |
| EC-09 | 无 Core checkpoint-as-transaction 声明 | RHEOVELA checkpoint/effect 测试：4/4 checkpoint 路径；Postgres store | checkpoint 重建、stale checkpoint、intent 保留和 effect-before-checkpoint 保留 | 业务 commit/checkpoint 失败恢复仍由消费者负责 |
| EC-10 | `pkg/agent` event-sink 测试（pre-invocation fail、terminal failure 不被掩盖） | PRAXOVELA/RHEOVELA effect 和 audit 测试 | callback/sink 失败会暴露，不会伪成功 | 持久确认、pre-execution gate 和 post-commit 证据需要产品策略 |
| EC-11 | `core-containment-baseline` 范围中的 Path/VFS/WASM 限制控制；containment 测试见 `docs/project/verification-evidence.md` | 没有声称真实隔离 | 本地 path、VFS 和 WASM 限制控制已做契约/单元测试 | **没有真实 sandbox 隔离**；需要外部 container/VM 证据 |
| EC-12 | 无 Core distributed-lock 声明 | EE Postgres nodes 6/6（lease/fencing/concurrent acquire）；RHEOVELA `ha_locks`/`stage_leases`/outbox 38/38；RHEOVELA 128-job + 1h soak | 真实 Postgres lease/fencing、outbox claim 和长时间本地并发 | 多进程部署 authority、tenant 隔离和生产负载仍为外部 |
| EC-13 | 无 Core 物理效果语义 | AKROVELA F5 本地 API/PostgreSQL 仿真（`a5e8e1d`，2026-11-22）：6/6 case，重复提交幂等，scope mismatch `403`，terminal restart 保留 receipt；E1-E8 确定性/本地组件矩阵（`f8fd4d7`，2026-11-22）全部通过；模拟 observation source 和 bridge backend；`stage_3_4_p2_acceptance=not_claimed` | 产品本地 fixture 中 accepted/completed/verified 仍保持区别；E1-E8 映射记录在 `docs/e1-e8-matrix.md` | **部分**；有命名消费者、本地 API 仿真和确定性/本地组件矩阵，但没有真实 ROS 2/Gazebo/Linux 执行、硬件效果、独立观测/验证者、G1-G8/E1-E8 端到端治理验收或已接受的 P2/P3 |
| EC-14 | `pkg/agent/resume_test.go::TestRunResumesFromSessionMessages`（属于 EC-D mechanics scope） | RHEOVELA Postgres store 38/38、HTTP effect、checkpoint 4/4；PRAXOVELA checkpoint/effect 测试 | 本地 resume 顺序，以及持久产品 store/checkpoint 契约 | 持久逻辑身份、业务去重和权威恢复仍由消费者负责 |
| EC-O | 无 Core 声明 | 无 | - | **Blocked**；没有部署环境、fault budget、权限或独立 AEP |

## 产品证据位置

| 产品 / 仓库 | 证据 | 不能证明 |
| --- | --- | --- |
| `praxo-core` | EC-D runner/inventory；Go agent/tool 测试；verification evidence | 消费者效果、sandbox、部署 |
| AKROVELA | F5 本地 API/PostgreSQL 仿真（2026-11-22）；P1 PRAXO-CORE slice；E1-E8 确定性/本地组件矩阵（2026-11-22） | 真实 ROS 2/Gazebo/Linux、硬件效果、独立 verifier、已接受 P2/P3 |
| RHEOVELA | Postgres store/effect/outbox/checkpoint/HTTP 测试；`demo-repository/praxovela-e2e` 中的 C9 | 生产执行 authority、外部 provider |
| PRAXOVELA | Effect ledger、A/B/C 边界、持久 outbox、replay 和 runtime options | 真实外部 provider 状态、完整 C separate-tx（C 是 A alias） |
| PRAXOVELA-EE | 产品入口审计/P0 测试 | 已部署 AEGIVELA/EIDOVELA 或多租户运营 |
| enterprise-autonomy | Reference adapter 和 vertical-slice 可执行证据 | 生产 OMS/payment/carrier/inference 系统 |
| demo-repository | C9 run record、60s/1h soak log | 独立或生产验证 |

## Tag 与发布上下文

| 仓库 | 当前 tag / 状态 | 需要 tag？ |
| --- | --- | --- |
| `praxo-core` | `v2.9.0`（2026-11-16 发布）；`v2.8.0`（2026-11-14）加入 safe-default guard、HITL 和 checkpoint 示例；`v2.6.0`（2026-11-07）包含 EC-01 行为修复、EC-D runner/scope 和本证据页。`2.9.0` 加入 memory recall trust 修复，不增加 EC 验收 | 这些变更不需要单独 tag；后续变更走正常 Core 发布门禁 |
| RHEOVELA | `v1.63.0` tag `59f66ed`；包含 lost-outcome 分类、已声明手动补偿、PostgreSQL `ON CONFLICT` 幂等和丢响应测试 | GitHub Release 已发布 source 和 release assets |
| PRAXOVELA | `v3.4.1` tag `bfcc5b0`；`PRAXOVELA-open` `v3.4.1` tag `4ccecb8`；包含 `9998c75` unknown tool-outcome 分类 | Core 和 open 的 GitHub Release 已发布 `axond` Windows/Linux binary、NSIS/MSI installer、SBOM、release manifest 和 `SHA256SUMS` |
| PRAXOVELA-open | `v3.4.0` | 必须匹配下一次 PRAXOVELA core release tag |
| PRAXOVELA-EE | 独立 tag | 本工作无代码变更；不需要 tag |
| `enterprise-autonomy` | `v1.1.13`；仅公开 docs/evidence | 除非仓库 docs-release policy 另行要求，否则不需要新 tag |
| `demo-repository` | `v0.2.0`；仅 evidence docs | 不需要新 tag |

本表记录证据快照时的状态，不是发布授权。source tag 不会把本地证据变成生产验收。
