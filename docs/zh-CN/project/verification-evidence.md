# 验证证据

**状态：** 公开证据摘要，2026-11-09。

本页汇总 PRAXO-CORE 当前可以支持的验证声明。它是公开摘要，不是生产认证、渗透测试，也不表示
每个语言实现和部署都会继承相同结果。完整运行记录和环境日志保存在受限内部存储；本页只记录
证据级别、结果和剩余限制。

记录要求见[测试证据规范](../contributing/test-evidence.md)：环境、配置、过程、数据、结果和发现。

## 证据级别

| 级别 | 含义 |
| --- | --- |
| 契约/单元 | 确定性仓库测试、fake、向量或 API 快照 |
| 本地集成 | 真实本地二进制和数据库，loopback，可丢弃状态 |
| 独立/生产 | 独立方复现或部署环境观察 |

除非某一行明确说明，当前公开证据不建立第三级。源码标签、矩阵中的 `complete` 或向量通过
都不是生产证据。

## 当前证据

| 领域 | 已验证 | 级别 | 限制 |
| --- | --- | --- | --- |
| Go Core | Tests、vet、build、API snapshot、race、fuzz 和 module-security CI；当前 main 与发布工作流检查；`v2.7.0` 为当前版本（2026-11-09）；`current-go-consumer` CI 任务从 Registry 安装推荐版本并运行确定性 allow/deny 检查；`v2.6.0` 可从公共 module proxy 在干净外部模块解析；另行记录的干净外部模块安装与最小 agent smoke 覆盖 `v2.5.2` | 契约/单元 + CI + 本地集成 | JSON Schema 和 plugin manifest fuzz 曾在 10s deadline 失败、rerun 通过；慢输入风险仍在调查；未重跑独立于 CI 的 `v2.7.0` 干净安装 smoke；已记录安装仅覆盖一个平台和最小 agent |
| Go 长时操作配方 | 文件存储覆盖幂等提交、响应丢失、子进程重启、独立 verifier、带 lease 过期/续期/撤销的 fencing、rename 前后确定性故障注入、损坏状态失败关闭、带 health/readiness、基础 metrics、示例 Prometheus scrape/留存/告警配置（仅配置校验；无 live collector）、环境变量配置、file-based token/secret 轮换（签发属外部）与优雅退出的独立服务二进制、可配置 file/SQLite/Postgres lease 后端与 reload-modify-save（SQLite 已验证；Postgres gated 测试需 `PRAXO_POSTGRES_DSN`，本环境未验证）、rename 边界前后进程级崩溃、gated 100 提交负载/故障测试与干净检出复现脚本、使用自己 token/密钥的独立 verifier 二进制，以及无 lease 时的并发写入者边界测试 | 契约/单元 + 本地集成 | L4 应用配方；没有生产部署、live collector/留存/告警、OS 级断电、生产 lease 协调、可信时钟或 exactly-once |
| 跨语言一致性 | Python、TypeScript、Java、Rust、Fortran、COBOL compatibility lab 运行确定性向量、API 快照/签名和 parity；已记录 Linux CI 与本地运行 | 契约/单元 + CI | 仅六种语言；COBOL 已在本地 GnuCOBOL 和 Linux CI 验证；不含 provider、HITL、checkpoint、sandbox 或生产证据；每次运行一个平台和工具链；非作者复现待办 |
| Python 已发布包 | PyPI 已从源码标签 `python/v0.4.1` 发布 `praxo-core==0.4.1`。发布工作流在发布前构建并 smoke 测试 wheel/sdist；该版本包含 Harmovela 与 MCP adapter。历史本地检查覆盖 `0.3.2` 与 `0.2.4` | Registry 发布 + 发布工作流产物 smoke + 发布后消费者检查 | 一个平台/工具链；同机干净 venv，不是独立或非作者消费者；不含 provider 或生产证据 |
| TypeScript 已发布包 | npm 已从源码标签 `typescript/v0.3.0` 发布 `@axisvela/praxo-core@0.3.0`，并作为 `latest`。发布工作流构建并消费 tarball；`0.3.0` README 包含绝对 registry/编程 Agent 链接；发布后消费者脚本曾对 `0.2.2` 在干净临时项目中通过 starter/治理检查，`0.3.0` 已在干净项目中安装并通过 starter 检查，治理负向套件未重跑。历史 smoke 覆盖 `0.1.5` | Registry 发布 + 发布工作流 tarball smoke + 历史发布后消费者检查 | 一个平台/工具链；不是独立消费者；不含 provider 或生产证据 |
| Rust 已发布 crate | crates.io 已从源码标签 `rust/v0.4.0` 发布 `praxo-core==0.4.0`；已记录的干净临时项目安装 smoke 覆盖 `0.1.4` | Registry 发布 + 历史本地安装 smoke | registry smoke 覆盖 `0.1.4`，不是 `0.4.0`；仅一个平台；不是独立消费者；不含 provider 或生产证据 |
| Dart 已发布包 | 从 pub.dev 在干净项目安装 `praxo_core==0.1.1`；程序导入 `package:praxo_core/praxo_core.dart`，并由最小 agent 返回 `hello` | 本地安装 smoke | 仅一个平台；同机项目，不是独立或非作者消费验证；仅最小 agent，不含 provider 或生产证据 |
| Ruby 已发布 gem | RubyGems 已从源码标签 `ruby/v0.4.1` 发布 `praxo-core==0.4.1`；gem 源码仓库为 `axisvela/praxo-core-ruby`。`0.4.0`、`0.3.0` 和 `0.2.0` 仍可用。已记录的干净临时目录 smoke 覆盖 `0.1.0` | Registry 发布 + 历史本地安装 smoke | 未对 `0.4.1` 重跑 registry 安装 smoke；仅一个平台；不是独立消费者；不含 provider 或生产证据 |
| Lua 已发布 rock | LuaRocks 已通过 `.github/workflows/lua-release.yml` 发布 `praxo-core==0.4.1-1`；工作流构建 source rock、在干净目录安装并运行安装后 smoke。已发布 `0.4.1-1` 也已安装到干净临时 tree，并从仓库外运行消费者 Starter 通过；`0.4.0-1`、`0.3.0-1` 和 `0.2.0-1` 仍可用 | Registry 发布 + CI 安装 smoke + 本地消费者安装 | 仅一个平台；不是独立消费者；不含 provider 或生产证据 |
| PHP 已发布包 | Packagist 从 split 标签 `v0.4.0` 发布 `axisvela/praxo-core==0.4.0`；`v0.3.0` 和 `v0.2.0` 仍可用 | Registry 发布 | 未记录 Composer 安装 smoke；仅一个平台；不是独立消费者；不含 provider 或生产证据 |
| C# 已发布包 | `Praxo.Core==0.4.0` 由 GitHub Actions Trusted Publishing 从源码标签 `csharp/v0.4.0` 完成构建、测试、打包并推送到 NuGet | CI + registry | 本地无 .NET SDK，未执行消费者安装 smoke；一个包版本；不含 provider 或生产证据 |
| MATLAB File Exchange 包 | `PRAXO-CORE 0.2.1` 已发布到 File Exchange 条目 `185166`，包含 toolbox image 和 MIT license | Registry 发布 | 未记录 MATLAB 运行时验证和消费者安装 smoke；Octave 验证不能证明 MATLAB 行为 |
| PowerShell Core | PowerShell Gallery 已发布 `praxo-core-ps==0.2.0`。CI 构建 C# Core，运行 C# conformance/behavior 套件、包装 smoke 和 PowerShell API snapshot | Registry + contract/unit + CI | 共享 C# 运行时，不是独立 agent loop；行为证据继承自 C# Core；尚无消费者安装 smoke 或 provider 证据 |
| Elixir 已发布包 | Hex 已从源码标签 `elixir/v0.4.1` 发布 `praxo_core==0.4.1` 与 HexDocs `0.4.1`；`0.4.0`、`0.3.0` 和 `0.2.0` 仍可用。`0.4.1` 已在干净 Mix 项目中解析，消费者 Starter 本地通过 | Registry 发布 + 本地消费者安装 | 仅一个平台；不是独立消费者；不含 provider 或生产证据 |
| Erlang 已发布包 | Hex 已从源码标签 `erlang/v0.4.0` 发布 `praxo_core_erlang==0.4.0`；`0.3.1` 和 `0.2.0` 仍可用。历史 `0.1.1` 曾由干净 rebar3 项目获取 | Registry 发布 + 历史本地安装 smoke | `0.4.0` 未重新执行消费者安装 smoke；仅一个平台；非独立消费者；不含 provider 或生产证据 |
| D 已发布包 | 从 DUB/code.dlang.org 使用 `dub fetch praxo-core` 获取 `praxo-core==0.1.0` | Registry 元数据 + 获取 | 未执行编译或独立消费者 smoke；一个包版本；不含 provider 或生产证据 |
| Java 已发布包 | Maven Central 已发布 `com.axisvela:praxo-core:0.5.0`，包含 sources、javadoc 和 GPG 签名。Central 在发布前校验 deployment；发布后消费者脚本曾对 `0.4.1` 通过 starter/治理检查，`0.5.0` 未重跑 | Registry 发布 + Central 校验 + 历史发布后消费者检查 | 一个 deployment/平台/工具链；不是独立消费者；不含 provider 或生产证据 |
| 扩展消费者 Starter（Ruby/PHP/Elixir/Lua） | `examples/consumer-ruby`、`consumer-php`、`consumer-elixir`、`consumer-lua` 的确定性允许/拒绝 Starter 在源码模式本地通过。配置本地代理 CA 后，RubyGems `praxo-core==0.4.1`、Hex `praxo_core==0.5.1`、LuaRocks `praxo-core==0.4.1-1` 均从仓库外安装并运行 Starter 通过。Composer 安装了已发布 `axisvela/praxo-core==0.4.1`，Starter 无需桥接即通过；包已声明 `autoload.files` 并包含 `api/0.4.1.txt` | 契约/单元 + 本地 registry 安装 | 扩展语言 Starter；不含治理负向矩阵；一个平台；不含 provider、身份、隔离或生产证据 |
| 跨语言 agent 行为 | 全部十六个已接入语言在源码中通过二十个授权、生命周期、取消、输入校验、调用上限、并行工具、run 隔离、PII、checkpoint、容量、SSE 截断、流失败和 HITL 决策场景。agent-capable 语言使用场景级或 self-test 覆盖，扩展语言使用原生套件覆盖；COBOL、Lua、PHP 和 Fortran 的并行工具委托给调用方提供的批处理回调。其他实现属于 optional。`b6218e5` 的 clean-tree CI 报告记录 320 passed、0 unsupported、无失败 | 场景测试 + CI | 十六个已接入语言在源码中均达到 20/20；部分扩展行为是套件级覆盖，失败不能定位到具体场景；`4ffd83b` 的本地报告是历史证据，不是当前证据；不是吞吐/压力测试，也不是完整功能对齐、provider、sandbox 或生产证据 |
| 受治理工作区 | Policy 必需配置、最终参数授权、单次审批、审批后修改、排队撤销、依赖失败关闭 | 契约/单元 | 示例级契约；不是 Core Profile、可信身份服务或持久审批存储 |
| 上下文信任 | Memory、Skill、工具结果和摘要来源分离；批准 Skill 摘要绑定；文本恢复；拒绝晚期 System 注入 | 契约/单元 | 显式示例路径；不是通用 Prompt Injection 过滤器、来源认证或持久 lineage 证明 |
| 隔离能力 | Windows path/process/WASM 控制；Linux path/symlink 的 verbose CI job；本地 VFS 在 policy 检查后使用 `os.Root` 执行实际操作 | 契约/单元 + CI | Windows symlink 因权限 SKIP；policy 决策仍是 check-then-use，Linux cgroup v2、WASM fuel 和独立复核仍开放 |
| 工作区适配器 | E2B、Daytona、OpenSandbox、CubeSandbox 的共享 conformance 和 fake-provider 测试 | 契约/单元 | 所有 live provider 测试因缺少凭证 SKIP；未晋级 contract |
| OpenTelemetry | 可运行内存示例生成 `run.started`、`tool.call`、`run.completed`；allowlist 排除工具参数/结果 | 示例 + 单元 | 未验证 collector、OTLP 后端、采样、保留或生产遥测 |
| A2A 互操作 | Google ADK 消费已发布 Core `v2.5.1` A2A，无本地 Core replace；成功、拒绝、失败、超时、认证、TLS、跨源和并发 fixture | 本地集成 | Loopback 确定性 fixture，不是部署 peer 或生产负载 |
| Agent IAM 契约 | Direct 与 gateway 形状的 Agent IAM 示例对契约 fake；凭证时间窗、key、签名和主体字段检查 | 契约/单元 | NOMIVELA/EIDOVELA/AEGIVELA 响应为 fake；demo 没有 proof 重放缓存或请求体绑定 gateway assertion |
| 编程 Agent Skill 发现 | Claude Code `2.1.196` 在临时 skills 目录插件中安装 `agent-skills/praxo-integration`；`plugin list` 显示已加载，`plugin details` 列出 Skill 组件（2026-11-08，`bdd36d7`；issue #15） | 本地结构检查 | 仅该工具和平台；该 CLI 未执行模型任务或发布包集成；不是采用证据 |
| 编程 Agent Skill 任务 | opencode `1.18.18` 从项目本地 `.opencode/skills/praxo-integration/SKILL.md` 发现 `agent-skills/praxo-integration`，并使用已发布 PyPI `praxo-core==0.3.2`、显式工具范围与 allow/deny 测试完成确定性 Python 任务（3/3 通过；模型 `deepseek/deepseek-flash`；Python 3.14.6；2026-11-08，`7004a08`） | 本地结构检查 + 本地任务执行 | 仅一个工具、一个任务、一个平台；首次通过且无需修复；未覆盖治理负向矩阵、live 模型、真实身份、持久审批、效果提交、exactly-once 或隔离；不是采用证据 |
| AKROVELA 嵌入 PRAXO-CORE | AKROVELA 通过产品侧适配器嵌入已发布 PRAXO-CORE `v2.6.0`：精确操作工具、强制 Policy、受限预算、脱敏遥测与 PostgreSQL Run/对账日志；使用测试模型和本地 PostgreSQL 的确定性切片已在 AKROVELA 仓库（`b5e5da9`，2026-11-08）记录为本地验证 | 本地集成（产品仓） | 没有生产模型 provider、Agent HTTP 端点、观测、独立验证者、ROS 2 执行、硬件效果、live KINETOVELA 集成或 E1-E8 试点运行；产品侧证据，不是 Core 验收 |
| 集成恢复 | 真实本地 Symbivela、Ontovela、Rheovela、Orchadyn、Praxovela、LIMENORA 和 integration-domain；8 步、5 产品、4 gates、13 证据、11/11 报告检查；preserve/verify 拒绝和 silent-rerun 拒绝 | 本地集成 | 可丢弃本地数据库和固定 ID；没有生产、网络分区、并发负载、独立复现或部署验证 |
| 产品效果账本 | RHEOVELA effect/durable/crash 和 PRAXOVELA tenant-scoped effect-ledger 测试，含内存/SQLite 生命周期与对账 | 契约/单元（产品仓） | 进程内 SQLite/temp 文件；不是 live PostgreSQL 集群或跨服务事务 |

## 公开证据链接

- [兼容性实验](../languages/compatibility-lab.md) 与 [已记录的 CI compatibility job](https://github.com/axisvela/praxo-core/actions/runs/41000572198/job/123883752839)
- [行为实验](../languages/behavior-lab.md) 与 [commit `b6218e5` 的 CI behavior job](https://github.com/axisvela/praxo-core/actions/runs/41407891314/job/125153985339)

CI 链接指向已记录的运行；它们只证明该 run 所指的 revision，不证明当前 `main` 已通过。
Registry 链接指向当前已发布版本；上表的消费者 smoke 行指明实际安装的版本。

- [PyPI 上的 praxo-core 0.3.2](https://pypi.org/project/praxo-core/0.3.2/)
- [npm 上的 @axisvela/praxo-core 0.3.0](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.3.0)
- [crates.io 上的 praxo-core 0.4.0](https://crates.io/crates/praxo-core/0.4.0)
- [pub.dev 上的 praxo_core 0.1.1](https://pub.dev/packages/praxo_core)
- [RubyGems 上的 praxo-core 0.4.1](https://rubygems.org/gems/praxo-core/versions/0.4.1)
- [LuaRocks 上的 praxo-core 0.4.1-1](https://luarocks.org/modules/hanhhuiwen/praxo-core)
- [Hex 上的 praxo_core 0.4.1](https://hex.pm/packages/praxo_core/0.4.1)
- [NuGet 上的 Praxo.Core 0.4.0](https://www.nuget.org/packages/Praxo.Core/0.4.0)
- [Packagist 上的 axisvela/praxo-core 0.4.0](https://packagist.org/packages/axisvela/praxo-core)
- [Hex 上的 praxo_core 0.4.0](https://hex.pm/packages/praxo_core/0.4.0)
- [Hex 上的 praxo_core_erlang 0.4.0](https://hex.pm/packages/praxo_core_erlang/0.4.0)
- [DUB 上的 praxo-core 0.1.0](https://code.dlang.org/packages/praxo-core)
- [Maven Central 上的 com.axisvela:praxo-core 0.5.0](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.5.0/)
- [受治理工作区示例](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace)
- [受治理执行设计](../reference/governed-execution.md)
- [OpenTelemetry 可运行示例](https://github.com/axisvela/praxo-core/tree/main/adapters/otel/example)
- [A2A 互操作示例](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-adk-order-cancellation)
- [Agent IAM 示例](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam)
- [集成恢复 demo](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/integration-recovery-local)
- [工作区适配器目录](https://github.com/axisvela/praxo-core/tree/main/adapters/workspace)
- [隔离能力评估](../security/containment.md)
- [RHEOVELA](https://github.com/axisvela/rheovela)、[PRAXOVELA](https://github.com/axisvela/praxovela) 与 [AKROVELA](https://github.com/axisvela/akrovela) 仓库

## 未声明

- 生产就绪、部署 SLO 或负载容量。
- 独立安全评审、渗透测试或合规认证。
- 通用 exactly-once 或跨服务事务。
- 外部工作区提供商的 live 验证。
- Live Postgres 验证：2026-11-09 在 Windows 上使用 PostgreSQL 18.1 的本地尝试未完成
  （服务以 `0xC0000142` 退出）；gated Postgres 测试需要 `PRAXO_POSTGRES_DSN` 和健康服务。
- 测试主机无法创建 symlink 时的 Windows symlink 隔离。
- 不同 commit、tag、二进制或依赖解析下的测试结果。
- 从源码标签推断包仓库可用性。

## 报告缺口

如果声明无法复现，请提交 issue，包含 commit、平台、命令、输入、预期结果、实际结果，以及
差异属于测试缺陷还是行为缺陷。不要用后续成功覆盖失败记录，二者都应保留。
