# 验证证据

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
| Go Core | Tests、vet、build、API snapshot、race、fuzz 和 module-security CI；当前 main 与发布工作流检查；已发布 `v2.5.2` 从干净外部模块无 `replace` 安装 | 契约/单元 + CI + 本地集成 | JSON Schema 和 plugin manifest fuzz 曾在 10s deadline 失败、rerun 通过；慢输入风险仍在调查；消费验证仅覆盖一个平台和最小 agent |
| 跨语言一致性 | Python、TypeScript、Java、Rust、Fortran、COBOL compatibility lab 运行确定性向量、API 快照/签名和 parity；已记录 Linux CI 与本地运行 | 契约/单元 + CI | 仅六种语言；COBOL 已在本地 GnuCOBOL 和 Linux CI 验证；不含 provider、HITL、checkpoint、sandbox 或生产证据；每次运行一个平台和工具链；非作者复现待办 |
| Python 已发布包 | 从 PyPI 在干净 venv 安装 `praxo-core==0.2.4`；包报告版本 `0.2.4`，最小 agent 返回最终答案 | 本地安装 smoke | 仅一个平台；同机干净 venv，不是独立或非作者消费验证；不含 provider 或生产证据 |
| TypeScript 已发布包 | 从 npm 在干净临时项目安装 `@axisvela/praxo-core@0.1.5`；包报告版本 `0.1.5`，导出 `Agent` 和 `Registry`，并报告 `SPEC_VERSION` `0.2.0` | 本地安装 smoke | 仅一个平台；同机临时项目，不是独立或非作者消费验证；仅导入 smoke，不含 provider 或生产证据 |
| Rust 已发布 crate | 从 crates.io 在干净临时项目安装 `praxo-core==0.1.4`；程序报告 `SDK_VERSION` `0.1.4` 和 `SPEC_VERSION` `0.2.0` | 本地安装 smoke | 仅一个平台；同机临时项目，不是独立或非作者消费验证；仅版本和导入 smoke，不含 provider 或生产证据 |
| Dart 已发布包 | 从 pub.dev 在干净项目安装 `praxo_core==0.1.1`；程序导入 `package:praxo_core/praxo_core.dart`，并由最小 agent 返回 `hello` | 本地安装 smoke | 仅一个平台；同机项目，不是独立或非作者消费验证；仅最小 agent，不含 provider 或生产证据 |
| Ruby 已发布 gem | 从 RubyGems 在干净临时目录安装 `praxo-core==0.1.0`；程序 `require 'praxo'` 并由最小 agent 返回 `hello` | 本地安装 smoke | 仅一个平台；同机临时目录，不是独立或非作者消费验证；仅最小 agent，不含 provider 或生产证据 |
| C# 已发布包 | `Praxo.Core==0.1.2` 由 GitHub Actions Trusted Publishing 完成构建、测试、打包并推送到 NuGet | CI + registry | 本地无 .NET SDK，未执行消费者安装 smoke；一个包版本；不含 provider 或生产证据 |
| Elixir 已发布包 | 从 Hex 在干净 Mix 项目安装 `praxo_core==0.1.1`；项目报告版本 `0.1.1` 并加载 `Praxo.Agent` | 本地安装 smoke | 仅一个平台；同机项目，不是独立或非作者消费验证；仅包发布，HexDocs 未发布；不含 provider 或生产证据 |
| Erlang 已发布包 | 干净 rebar3 项目获取并编译 `praxo_core_erlang==0.1.1`，并从该包加载 `praxo_agent` | 本地安装 smoke | 仅一个平台；同机项目，不是独立或非作者消费验证；不含 provider 或生产证据 |
| D 已发布包 | 从 DUB/code.dlang.org 使用 `dub fetch praxo-core` 获取 `praxo-core==0.1.0` | Registry 元数据 + 获取 | 未执行编译或独立消费者 smoke；一个包版本；不含 provider 或生产证据 |
| Java 已发布包 | `com.axisvela:praxo-core:0.3.0` 已发布到 Maven Central，包含 sources、javadoc 和 GPG 签名 | 本地发布 + Central 校验 | 本地 Maven 经代理部署；未执行独立消费者安装 smoke；不含 provider 或生产证据 |
| 跨语言 agent 行为 | Go、Python、TypeScript、Java 运行十九个授权、生命周期、取消、输入校验、调用上限、并行工具、run 隔离、PII、checkpoint、容量、SSE 截断和流失败场景；Rust 有部分场景级测试；Fortran/COBOL/Ruby/Elixir/Erlang/C++/PHP/C#/Lua 对部分行使用原生套件覆盖；已记录 Linux CI 与本地报告 | 场景测试 + CI | 核心覆盖为四种语言和十九个场景；扩展语言为套件级覆盖；部分 Java 组 self-test 与原生套件不能定位具体场景失败；不是吞吐/压力测试；不是完整功能对齐、provider、HITL、sandbox 或生产证据 |
| 受治理工作区 | Policy 必需配置、最终参数授权、单次审批、审批后修改、排队撤销、依赖失败关闭 | 契约/单元 | 示例级契约；不是 Core Profile、可信身份服务或持久审批存储 |
| 上下文信任 | Memory、Skill、工具结果和摘要来源分离；批准 Skill 摘要绑定；文本恢复；拒绝晚期 System 注入 | 契约/单元 | 显式示例路径；不是通用 Prompt Injection 过滤器、来源认证或持久 lineage 证明 |
| 隔离能力 | Windows path/process/WASM 控制；Linux path/symlink 的 verbose CI job；本地 VFS 在 policy 检查后使用 `os.Root` 执行实际操作 | 契约/单元 + CI | Windows symlink 因权限 SKIP；policy 决策仍是 check-then-use，Linux cgroup v2、WASM fuel 和独立复核仍开放 |
| 工作区适配器 | E2B、Daytona、OpenSandbox、CubeSandbox 的共享 conformance 和 fake-provider 测试 | 契约/单元 | 所有 live provider 测试因缺少凭证 SKIP；未晋级 contract |
| OpenTelemetry | 可运行内存示例生成 `run.started`、`tool.call`、`run.completed`；allowlist 排除工具参数/结果 | 示例 + 单元 | 未验证 collector、OTLP 后端、采样、保留或生产遥测 |
| A2A 互操作 | Google ADK 消费已发布 Core `v2.5.1` A2A，无本地 Core replace；成功、拒绝、失败、超时、认证、TLS、跨源和并发 fixture | 本地集成 | Loopback 确定性 fixture，不是部署 peer 或生产负载 |
| Agent IAM 契约 | Direct 与 gateway 形状的 Agent IAM 示例对契约 fake；凭证时间窗、key、签名和主体字段检查 | 契约/单元 | NOMIVELA/EIDOVELA/AEGIVELA 响应为 fake；demo 没有 proof 重放缓存或请求体绑定 gateway assertion |
| 集成恢复 | 真实本地 Symbivela、Ontovela、Rheovela、Orchadyn、Praxovela、LIMENORA 和 integration-domain；8 步、5 产品、4 gates、13 证据、11/11 报告检查；preserve/verify 拒绝和 silent-rerun 拒绝 | 本地集成 | 可丢弃本地数据库和固定 ID；没有生产、网络分区、并发负载、独立复现或部署验证 |
| 产品效果账本 | RHEOVELA effect/durable/crash 和 PRAXOVELA tenant-scoped effect-ledger 测试，含内存/SQLite 生命周期与对账 | 契约/单元（产品仓） | 进程内 SQLite/temp 文件；不是 live PostgreSQL 集群或跨服务事务 |

## 公开证据链接

- [兼容性实验](../languages/compatibility-lab.md) 与 [CI compatibility job](https://github.com/axisvela/praxo-core/actions/runs/41000572198/job/123883752839)
- [行为实验](../languages/behavior-lab.md) 与 [CI behavior job](https://github.com/axisvela/praxo-core/actions/runs/41210022256/job/124562871079)
- [PyPI 上的 praxo-core 0.2.4](https://pypi.org/project/praxo-core/0.2.4/)
- [npm 上的 @axisvela/praxo-core 0.1.5](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.1.5)
- [crates.io 上的 praxo-core 0.1.4](https://crates.io/crates/praxo-core/0.1.4)
- [pub.dev 上的 praxo_core 0.1.1](https://pub.dev/packages/praxo_core)
- [RubyGems 上的 praxo-core 0.1.0](https://rubygems.org/gems/praxo-core/versions/0.1.0)
- [LuaRocks 上的 praxo-core 0.1.0-1](https://luarocks.org/modules/hanhhuiwen/praxo-core)
- [NuGet 上的 Praxo.Core 0.1.2](https://www.nuget.org/packages/Praxo.Core/0.1.2)
- [Hex 上的 praxo_core 0.1.1](https://hex.pm/packages/praxo_core/0.1.1)
- [Hex 上的 praxo_core_erlang 0.1.1](https://hex.pm/packages/praxo_core_erlang/0.1.1)
- [DUB 上的 praxo-core 0.1.0](https://code.dlang.org/packages/praxo-core)
- [Maven Central 上的 com.axisvela:praxo-core 0.3.0](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.3.0/)
- [受治理工作区示例](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace)
- [受治理执行设计](../reference/governed-execution.md)
- [OpenTelemetry 可运行示例](https://github.com/axisvela/praxo-core/tree/main/adapters/otel/example)
- [A2A 互操作示例](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-adk-order-cancellation)
- [Agent IAM 示例](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam)
- [集成恢复 demo](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/integration-recovery-local)
- [工作区适配器目录](https://github.com/axisvela/praxo-core/tree/main/adapters/workspace)
- [隔离能力评估](../security/containment.md)
- [RHEOVELA](https://github.com/axisvela/rheovela) 与 [PRAXOVELA](https://github.com/axisvela/praxovela) 仓库

## 未声明

- 生产就绪、部署 SLO 或负载容量。
- 独立安全评审、渗透测试或合规认证。
- 通用 exactly-once 或跨服务事务。
- 外部工作区提供商的 live 验证。
- 测试主机无法创建 symlink 时的 Windows symlink 隔离。
- 不同 commit、tag、二进制或依赖解析下的测试结果。
- 从源码标签推断包仓库可用性。

## 报告缺口

如果声明无法复现，请提交 issue，包含 commit、平台、命令、输入、预期结果、实际结果，以及
差异属于测试缺陷还是行为缺陷。不要用后续成功覆盖失败记录，二者都应保留。
