# 验证证据

**状态：** 公开证据摘要，2026-11-27 更新；当前核心版本 `2.11.3`。历史记录保留原 revision 和限制。

本页汇总 PRAXO-CORE 当前可以支持的验证声明。它是公开摘要，不是生产认证、渗透测试，也不表示
每个语言实现和部署都会继承相同结果。完整运行记录和环境日志保存在受限内部存储；本页只记录
证据级别、结果和剩余限制。

记录要求见[测试证据规范](../../contributing/test-evidence.md)：环境、配置、过程、数据、结果和发现。

## 相关页面

- [契约状态](../status/contract-status.md)：汇总状态用语与当前实现状态。
- [执行正确性证据](execution-correctness-evidence.md)：把正确性要求映射到证据。
- [路线图](../planning/roadmap.md)：说明公开方向与优先级。

## 证据级别

| 级别 | 含义 |
| --- | --- |
| 契约/单元 | 确定性仓库测试、fake、向量或 API 快照 |
| 本地集成 | 真实本地二进制和数据库，loopback，可丢弃状态 |
| 独立/生产 | 独立方复现或部署环境观察 |

除非某一行明确说明，当前公开证据不建立第三级。源码标签、矩阵中的 `complete` 或向量通过
都不是生产证据。

## 当前证据

下文包版本与 registry 观察保留各次运行的历史快照，不是当前发布索引。
当前发布版本见[公开证据链接](#公开证据链接)和 [Registry 发布状态](../../languages/registry-status.md)。
更新链接不代表新增消费者安装或升级验证。

详细证据分为[Core 与执行](verification-core-and-execution.md)和[应用](verification-applications.md)。

### 教程 CI 后续记录（2026-11-25） {#tutorial-ci-follow-up-2026-11-25}

Moved to [教程 CI 后续记录（2026-11-25）](verification-core-and-execution.md#tutorial-ci-follow-up-2026-11-25).

### Core、执行与真实模型 {#core-execution-and-live-model}

Moved to [Core、执行与真实模型](verification-core-and-execution.md#core-execution-and-live-model).

### 发布包、身份示例与消费者运行 {#packages-identity-examples-and-consumer-runs}

Moved to [发布包、身份示例与消费者运行](verification-core-and-execution.md#packages-identity-examples-and-consumer-runs).

### 参考应用 {#reference-applications}

Moved to [参考应用](verification-applications.md#reference-applications).

### 跨语言行为与集成安全 {#cross-language-behavior-and-integration-safety}

Moved to [跨语言行为与集成安全](verification-core-and-execution.md#cross-language-behavior-and-integration-safety).

### 编程 Agent 与采用 {#coding-agent-and-adoption}

Moved to [编程 Agent 与采用](verification-applications.md#coding-agent-and-adoption).

### 产品与具身证据 {#product-and-embedded-evidence}

Moved to [产品与具身证据](verification-applications.md#product-and-embedded-evidence).

## 公开证据链接

- [兼容性实验](../../languages/compatibility-lab.md) 与 [已记录的 CI compatibility job](https://github.com/axisvela/praxo-core/actions/runs/41000572198/job/123883752839)
- [行为实验](../../languages/behavior-lab.md) 与 [commit `b6218e5` 的 CI behavior job](https://github.com/axisvela/praxo-core/actions/runs/41407891314/job/125153985339)

CI 链接指向已记录的运行；它们只证明该 run 所指的 revision，不证明当前 `main` 已通过。
Registry 链接指向当前已发布版本；上表的消费者 smoke 行指明实际安装的版本。

- [Registry 发布状态（当前版本与地址）](../../languages/registry-status.md)
- [PyPI 上的 praxo-core 0.11.2](https://pypi.org/project/praxo-core/0.11.2/)
- [npm 上的 @axisvela/praxo-core 0.10.1](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.10.1)
- [crates.io 上的 praxo-core 0.11.1](https://crates.io/crates/praxo-core/0.11.1)
- [pub.dev 上的 praxo_core 0.8.2](https://pub.dev/packages/praxo_core/versions/0.8.2)
- [RubyGems 上的 praxo-core 0.10.2](https://rubygems.org/gems/praxo-core/versions/0.10.2)
- [LuaRocks 上的 praxo-core 0.9.1-1](https://luarocks.org/modules/hanhhuiwen/praxo-core/0.9.1-1)
- [Hex 上的 praxo_core 0.11.1](https://hex.pm/packages/praxo_core/0.11.1)
- [NuGet 上的 Praxo.Core 0.11.1](https://www.nuget.org/packages/Praxo.Core/0.11.1)
- [Packagist 上的 axisvela/praxo-core 0.10.2](https://packagist.org/packages/axisvela/praxo-core/0.10.2)
- [PowerShell Gallery 上的 praxo-core-ps 0.9.1](https://www.powershellgallery.com/packages/praxo-core-ps/0.9.1)
- [MetaCPAN 上的 Praxo-Core 0.8.1](https://metacpan.org/release/HANHHUIWEN/Praxo-Core-0.8.1)
- [Hex 上的 praxo_core_erlang 0.10.1](https://hex.pm/packages/praxo_core_erlang/0.10.1)
- [DUB 上的 praxo-core 0.8.0](https://code.dlang.org/packages/praxo-core/versions/0.8.0)
- [Maven Central 上的 com.axisvela:praxo-core 0.12.3](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.3/)
- [受治理工作区示例](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/governed-workspace)
- [受治理执行设计](../../reference/governed-execution.md)
- [OpenTelemetry 可运行示例](https://github.com/axisvela/praxo-core/tree/main/adapters/otel/example)
- [A2A 互操作示例](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-adk-order-cancellation)
- [Agent IAM 示例](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam)
- [集成恢复 demo](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/integration-recovery-local)
- [工作区适配器目录](https://github.com/axisvela/praxo-core/tree/main/adapters/workspace)
- [隔离能力评估](../../security/containment.md)
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
- CI 全绿。取消、失败或未运行的 job 都不是通过；请查看已记录的 CI 链接及其限制。

## 报告缺口

如果声明无法复现，请提交 issue，包含 commit、平台、命令、输入、预期结果、实际结果，以及
差异属于测试缺陷还是行为缺陷。不要用后续成功覆盖失败记录，二者都应保留。
