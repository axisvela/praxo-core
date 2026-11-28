# 验证证据：应用

参考应用、编程 Agent、采用与嵌入式产品证据。

## 相关页面

- [验证证据](verification-evidence.md)：证据层级、索引与限制。
- [执行正确性证据](execution-correctness-evidence.md)：要求级正确性证据。
- [契约状态](../status/contract-status.md)：当前实现状态。


## 参考应用 {#reference-applications}

**CI 后续记录，2026-11-26 审核：** 两个 PHP 作业（Composer 安装与 PHPUnit）于 2026-11-25 在
[45655799714](https://github.com/axisvela/praxo-core/actions/runs/45655799714)、
`92ba764ca54a2f4d9d0d2223aea16001c6e0c221` 通过。该运行因 C++ CMake 配置失败而整体失败，
其他应用作业被跳过。[45720963270](https://github.com/axisvela/praxo-core/actions/runs/45720963270)、
`f8242fb33a84a66b5c0590ea1de50266b5bd46ce` 仅通过 C++ 静态库构建与归档存在检查，
包括 PHP、Java 在内的其他应用作业全部跳过。这不是全部应用或 SDK 全面 CI 通过。

2026-11-28，`ci-applications` 的 `java-ai-commerce` 在
[46018135957，attempt 2](https://github.com/axisvela/praxo-core/actions/runs/46018135957/attempts/2)、
`b531f6abdfc1775ce5122357c496d834428cfe63` 通过。首次因 Maven 解析 Core `0.12.3` 失败；
仅重跑失败作业，其他应用跳过。这是托管确定性构建/测试证据，不是整个组合通过。
本地 Windows JVM 仍阻塞，Java 没有真实模型运行记录。

八项优先级均有源码，不等于完整宿主验收。Java 已有上述限定范围的托管确定性通过；C++ 仅构建，无运行时/真实模型运行。
Go 的 module replace 与 Rust 的 path 依赖使用本地 Core 源码，不是 registry 包。
PHP/Elixir/Erlang/Go/Rust/Julia/Ruby 的七个托管参考应用运行不验证 #31 单独跟踪的
发布包 starter 托管端点路径。

下表保留 2026-11-25 最初的本地工作区快照。“尚未提交/revision 待定”描述当时运行，
不是当前仓库状态。后续 CI 与这些本地结果分别记录。

| 领域 | 已验证 | 级别 | 限制 |
| --- | --- | --- | --- |
| PHP Laravel 内容审阅前驱 | 2026-11-25 本地工作区（尚未提交）：`language/php/application/content-review` 安装已发布 `axisvela/praxo-core==0.8.1` 与 Laravel `12.74.0`；`vendor/bin/phpunit` 7/7 通过、29 条断言。覆盖文章审阅草案 `publications_executed=0`、缺失/错误租户在读取内容前被拒绝、`article-200` 策略拒绝且零读取零草案、依赖失败在一次读取后返回 `TOOL_ERROR` 且无草案，以及 Artisan 成功/失败路径。`php artisan content:review-article article-100` 报告 `reads=1`、`drafts=1`、`publications_executed=0`；`article-200` 以 `AGENT_POLICY_DENIED` 退出 1；`--simulate-failure` 以 `TOOL_ERROR` 退出 1。后续应用 CI 已在 `45655799714`、`92ba764c` 通过 | 契约/单元 + 本地宿主运行 + CI | PHP 8.5.12，手动启用扩展并使用本地 CA/代理 workaround；确定性模型与内存 fixture 文章存储；这是宿主集成前驱，不是 AI-native 编辑工作室；不含真实 Provider、托管服务、真实 CMS 数据库、生产身份或独立消费者；本地快照 revision 待定，CI revision 单独记录 |
| PHP AI-native 编辑工作室 | 2026-11-25 本地工作区（尚未提交）：`language/php/application/ai-editorial-studio` 安装已发布 `axisvela/praxo-core==0.8.1` 与 Laravel `12.74.0`；`vendor/bin/phpunit` 9/9 通过、56 条断言。选题流程检索来源、保存模型生成的 `draft_only` 草案、附加分类并创建 `review_requested` 请求，`publications_executed=0`；仓库计数为一份草案、一次审阅、零发布。`Publish immediately: ...`、租户和内容索引失败均有覆盖。另使用托管 DeepSeek `deepseek-flash` 完成真实运行：`model=live`，四步 trace（`search_content` -> `draft_article` -> `suggest_taxonomy` -> `request_publish_review`），模型理由（最近一次 858 字符），`publications_executed=0`；模型明确避免编造 Q3 运营数据，改用占位符。真实运行使用自定义 cURL transport 处理本地代理/CA。后续应用 CI 已在 `45655799714`、`92ba764c` 通过 | 契约/单元 + 本地宿主运行 + 托管真实模型 + CI | 确定性与托管真实运行；fixture 内容索引与内存草案/审阅仓库；无 Drupal 宿主、真实 CMS、持久草案存储、生产身份、独立消费者或生产部署；真实运行使用自定义 transport；本地快照 revision 待定，CI revision 单独记录 |
| Java AI 电商助手（仅源码） | 源码已添加到 `language/java/application`：Spring Boot `4.1.0`、已发布 `com.axisvela:praxo-core:0.11.0`、租户过滤器、应用自有商品/草案服务、五个工具且 `checkout` 始终拒绝、模型理由与 `agent_trace`、确定性模型、六个主测试加一个商品目录失败测试。本地 JDK 25 JVM 即使重定向 stdin 仍挂起，因此没有本地编译、测试或真实运行结果。Linux CI 作业已添加但尚未运行 | 源码 / CI 待运行（未验证） | 无本地编译或测试结果；无真实模型运行；无 CI 结果；无真实 Provider、支付、真实商品目录、生产身份或独立消费者；CI 记录前不得声称 Java 测试或真实推理通过 |
| Elixir AI 运维 Copilot | 2026-11-25 本地工作区（尚未提交）：`language/elixir/application` 在 Elixir `1.20.4` / OTP `29` 上；`PRAXO_CORE_PATH=.. mix test` 6/6 通过。应用监督遥测存储与修复执行器；成功生成 `draft_only` 修复，包含模型 diagnosis/rationale 且 `executions=0`；直接修复请求被策略拒绝且零效果；`service-200` 与错误租户在读取前被拒绝；遥测失败在一次读取后返回 `TELEMETRY_UNAVAILABLE` 且无草案；杀掉遥测进程后监督树以新 PID 重启。另使用托管 DeepSeek `deepseek-flash` 完成真实运行：`model=live`，模型选择 `search_signals(service-100)`，再生成包含 diagnosis/rationale 的 `draft_remediation`，最终 `executions=0`。更早一次尝试把展示名 `checkout` 当作 service id，被策略拒绝；加入授权 service id 后模型自行改对 | 契约/单元 + 本地 OTP 宿主 + 托管真实模型 | 源码模式确定性测试与 `:httpc` 代理/CA 真实运行；本地 Hex 与 CI 未运行；fixture 遥测与内存执行器；无真实遥测、生产集群、真实修复、持久状态、生产身份、独立消费者或生产部署；提交 revision 待定 |
| Erlang AI 运维 Copilot | 2026-11-25 本地工作区（尚未提交）：`language/erlang/application` 使用 OTP `29` 编译 Erlang Core 源码与 OTP 应用，`python language/erlang/application/run-tests.py` 6/6 通过。应用监督遥测存储与修复执行器；成功生成 `draft_only` 修复，包含模型 diagnosis/rationale 且 `executions=0`；直接修复、`service-200` 与错误租户被拒绝；遥测失败在一次读取后返回 `TELEMETRY_UNAVAILABLE`；杀掉遥测进程后监督树重启。另使用托管 DeepSeek `deepseek-flash` 完成真实运行：`model=live`，模型选择 `search_signals(service-100)`，再生成包含 diagnosis/rationale 的 `draft_remediation`，最终 `executions=0`；transport 使用 `httpc` 与代理/CA | 契约/单元 + 本地 OTP 宿主 + 托管真实模型 | 源码模式编译 Core，不是 registry/rebar 安装；Erlang CI 已添加但未运行；fixture 遥测与内存执行器；无真实遥测、生产集群、真实修复、持久状态、生产身份、独立消费者或生产部署 |
| Go AI 基础设施 Agent | 2026-11-25 本地工作区（尚未提交）：`language/go/application` 通过本地 module replace 使用 Go 参考源码；`go test ./...` 8/8 通过。应用提供 HTTP 与 CLI 入口、租户校验、应用自有遥测/执行器服务、受治理工具和 `agent_trace`。成功返回 `draft_only` 修复，包含模型 diagnosis/rationale 且 `executions=0`；直接修复、`service-200` 与错误租户被拒绝；遥测失败返回 `TOOL_ERROR`；无效模型输出被拒绝。另使用托管 DeepSeek `deepseek-flash` 完成真实运行：`model=live`，三步 trace（`search_signals` -> `draft_remediation` -> 最终报告），350 字符 diagnosis、523 字符 rationale，`executions=0` | 契约/单元 + 本地 Go 宿主 + 托管真实模型 | 本地 module replace，不是 registry 安装；Go CI 已添加但未运行；fixture 遥测与内存执行器；无真实遥测、生产集群、真实修复、持久状态、生产身份、独立消费者或生产部署 |
| Rust AI 边缘网关 Agent | 2026-11-25 本地工作区（尚未提交）：`language/rust/application` 使用本地 path 依赖指向 Rust 参考源码；`cargo test --offline` 6/6 通过。CLI 使用应用自有 `GatewayAdapter`、受治理工具、策略和 `agent_trace`。成功生成 `draft_only` 修复，包含 diagnosis/rationale 且 `executions=0`；直接修复、`device-200` 与错误租户被拒绝；网关失败返回 `TOOL_ERROR`；无效模型输出被拒绝。托管 DeepSeek `deepseek-flash` 真实运行记录 `model=live`、模型选择 `read_gateway` 再选择 `draft_action`、模型生成 diagnosis/rationale 和 `executions=0`；live 路径使用应用自有 `curl` transport，不使用 Core `http-ureq`/`ring` 构建，Windows 添加 `--ssl-no-revoke` | 契约/单元 + 本地 Rust 宿主 + 托管真实模型 | 本地 path 依赖，不是 crate registry 证据；Rust CI 已添加但未运行；fixture adapter 与确定性模型加托管真实运行；无真实 MQTT、OPC UA、Socket、设备写入、生产身份、独立消费者或生产部署 |
| C++ AI 工业边缘 Agent | 2026-11-25 本地工作区（尚未提交）：`language/cpp/application` 通过本地 Core CMake target 与 MinGW 构建，只生成 `libpraxo-cpp-ai-edge-application.a`。由于 SEP 拦截可执行产物，本仓库不生成 exe。源码包含应用自有 `GatewayAdapter`、受治理工具、策略和 trace 代码，以及仅源码的 `curl` live transport，但没有本地运行测试或真实模型运行。CMake 配置在 `45655799714` 失败；静态库构建与归档检查在 `45720963270`、`f8242fb3` 通过 | 源码/静态库编译 + CI 仅构建 | 本地 Core CMake/源码构建，不是 registry 包证据；本仓库不生成可执行文件；无本地或 CI 运行时/真实模型运行；后续成功运行中其他应用作业被跳过；无真实现场总线/OPC UA/设备写入、生产身份、独立消费者或生产部署 |
| COBOL AI 批处理异常分析 Agent | 2026-11-25 本地工作区（尚未提交）：`language/cobol/application` 使用 GnuCOBOL `2.0.0` 编译原生 COBOL Core；`python language/cobol/application/run-tests.py` 通过五项内部检查和批处理文件检查。COBOL `praxo-run` 循环读取 `exceptions.tsv`，调用模型选择的 `read_exception` 与 `draft_advisory`，并把只读建议写入 `advisory.tsv`。公开记录成功生成 diagnosis/rationale 且 `executions=0`；私密记录在读取前被拒绝；直接 `post_adjustment` 被拒绝且零效果；租户不匹配在模型前被拒绝；缺少 diagnosis/rationale 的弱建议被拒绝。可执行文件仅位于被忽略的 `language/cobol/build/`，不提交二进制 | 契约/单元 + 本地 GnuCOBOL 宿主 | 原生 COBOL 源码构建，不是 registry 包安装；COBOL CI 已添加但未运行；fixture 异常文件与确定性脚本模型；无真实模型 transport、真实账本/过账/清算、持久队列/恢复、生产身份、独立消费者或生产部署 |
| Julia AI 科学计算 Copilot | 2026-11-25 本地工作区（尚未提交）：`language/julia/application` 在 Julia `1.13.2` 上运行；`julia --project=language/julia language/julia/application/application.jl --test` 六项检查通过。原生 `praxo-run` Agent 调用 `load_observations` 与 `fit_response_surface`；拟合使用 `LinearAlgebra` 对 11 个 fixture 样本做普通最小二乘。成功记录 R² `0.999995`、边界内最优 `0.6994`、预测产量 `0.91764`、`writes=0` 和 `mutating_actions=[]`；直接 `publish_experiment` 被策略拒绝；其他数据集在读取前被拒绝；未加载先拟合返回工具错误；租户不匹配在模型前被拒绝；模拟数值依赖失败后 `writes=0`。托管 DeepSeek `deepseek-flash` 真实运行记录 `model=live`、模型选择 `load_observations` 再选择 `fit_response_surface`、计算拟合证据和 `writes=0`；Windows transport 使用 `curl.exe --ssl-no-revoke` 与 `HTTPS_PROXY` | 契约/单元 + 本地 Julia 宿主 + 托管真实模型 | fixture 观测与单一二次模型；无实验数据库、统计验证、求解器认证、不确定性评估、仪表盘、实验记录写入、生产身份、独立消费者或生产部署；本地源码运行时，不是 registry 安装；Julia CI 已添加但未运行 |
| Ruby AI 商务 Copilot | 2026-11-25 本地工作区（尚未提交）：`language/ruby/application` 在 Ruby `3.4.12` 上以 `railties`/`actionpack` 启动 Rails `8.1.4.1`；`ruby language/ruby/application/run-tests.rb` 五项检查通过。Rails 控制器接受 `POST /assistant` 与租户 `acme`；原生 Ruby `praxo-run` 循环调用模型选择的 `search_catalog`、`quote_cart` 和 `draft_order`，在应用自有 store 中保存 `draft_only` 订单。成功记录 `$105.84` 报价、`payment_charges=0`、`refunds=0` 和 `mutating_actions=[]`；直接 `charge_payment` 与 `refund_order` 被策略拒绝；缺失或错误租户在 Agent 前被拒绝；缺少审阅字段的弱草案被拒绝且不持久化。托管 DeepSeek `deepseek-flash` 真实运行记录 `model=live`、多次 `search_catalog`、随后 `quote_cart` 与 `draft_order`、`draft_only` 订单和零支付/退款效果；Windows transport 使用 `curl.exe --ssl-no-revoke` 与代理 | 契约/单元 + 本地 Rails 宿主 + 托管真实模型 | fixture 目录与内存草案存储；无生产数据库、Active Record 模型、Active Job worker、库存预留、持久审计存储、真实支付/退款/税务/履约、生产身份、独立消费者或生产部署；最小 Rails 宿主，不是完整生成的 Rails 应用；本地源码运行时，不是 registry 安装；Ruby CI 已添加但未运行 |
| 参考应用真实推理 | PHP AI 编辑工作室、Elixir AI 运维 Copilot、Erlang AI 运维 Copilot、Go AI 基础设施 Agent、Rust AI 边缘网关 Agent、Julia AI 科学计算 Copilot 与 Ruby AI 商务 Copilot 已在 2026-11-25 使用托管 DeepSeek `deepseek-flash` 记录真实推理。Java AI 电商有源码级 trace/rationale，但无编译或真实运行；C++ 为源码/静态库集成，无 exe 或运行时执行；COBOL 有确定性测试但没有捆绑 HTTP/TLS transport。确定性脚本模型仍是 harness 测试 | 本地托管真实模型集成（PHP/Elixir/Erlang/Go/Rust/Julia/Ruby）；仅源码（Java/C++/COBOL） | PHP 使用自定义 cURL transport；Elixir/Erlang 使用 `httpc` 代理/CA；Go 使用默认 OpenAI-compatible client；Rust、Julia 与 Ruby 使用应用自有 `curl` transport；C++/COBOL live 缺失；无独立复现、生产部署、成本/延迟测试、Drupal/支付/真实遥测或生产身份 |


## 编程 Agent 与采用 {#coding-agent-and-adoption}

| 领域 | 已验证 | 级别 | 限制 |
| --- | --- | --- | --- |
| 编程 Agent Skill 发现 | Claude Code `2.1.196` 在临时 skills 目录插件中安装 `agent-skills/praxo-integration`；`plugin list` 显示已加载，`plugin details` 列出 Skill 组件（2026-11-08，`bdd36d7`；issue #15） | 本地结构检查 | 仅该工具和平台；该 CLI 未执行模型任务或发布包集成；不是采用证据 |
| 编程 Agent Skill 任务 | opencode `1.18.18` 从项目本地 `.opencode/skills/praxo-integration/SKILL.md` 发现 `agent-skills/praxo-integration`，并使用已发布 PyPI `praxo-core==0.3.2`、显式工具范围与 allow/deny 测试完成确定性 Python 任务（3/3 通过；模型 `deepseek/deepseek-flash`；Python 3.14.6；2026-11-08，`7004a08`） | 本地结构检查 + 本地任务执行 | 仅一个工具、一个任务、一个平台；首次通过且无需修复；未覆盖治理负向矩阵、live 模型、真实身份、持久审批、效果提交、exactly-once 或隔离；不是采用证据 |


## 产品与具身证据 {#product-and-embedded-evidence}

| 领域 | 已验证 | 级别 | 限制 |
| --- | --- | --- | --- |
| AKROVELA 嵌入 PRAXO-CORE | AKROVELA 通过产品侧适配器嵌入已发布 PRAXO-CORE `v2.10.0`：精确操作工具、强制 Policy、受限预算、脱敏遥测与 PostgreSQL Run/对账日志。AKROVELA 仓库记录使用测试模型和本地 PostgreSQL 的确定性 P1 切片（`b5e5da9`，2026-11-08）、F5 本地 API/PostgreSQL 仿真（`a5e8e1d`，2026-11-22）与 E1-E8 确定性/本地组件矩阵（`f8fd4d7`，2026-11-22）。F5 运行 6/6 用例通过，重复提交保持幂等、scope 不匹配返回 `403`、API 终态重启保留 receipt，`full_api_e2e=local_dev_passed`、`database_receipt_durability=terminal_restart_verified`、`mid_execution_crash_recovery=verified`；`stage_3_4_p2_acceptance=not_claimed`。E1-E8 矩阵通过全部八项要求；这不是 P2 验收。G1-G8 确定性/本地组件矩阵在 `907b1eb`（2026-11-22）映射 46 个测试，全部通过，包括 G2 未暴露工具拒绝与 G6 装配、压缩、offload、恢复；G2/G6 仿真不适用于 F5 直接操作 API，因此不声称完整 P2 验收。产品已于 2026-11-22 在 `9ac0e53` 从 Core `v2.6.0` 升级到 `v2.10.0`，并在 `054e98a` 记录验证；`go build ./...`、`go vet ./...` 与 `go test ./...` 通过，包括针对一次性本地 PostgreSQL 17 数据库的 PostgreSQL-gated recorder/runtime 测试。 | 本地集成（产品仓）；组件/fixture 范围 | 没有生产模型 provider、Agent HTTP 端点、真实 ROS 2/Gazebo/Linux 执行、硬件效果、独立观测源/验证者、live KINETOVELA 集成或 E1-E8 试点验收；F5 API 运行使用模拟 bridge/source 与一次性本地数据库；E1-E8 与 G1-G8 矩阵是确定性/本地组件证据，不是 P2 仿真验收；G1-G8 的 G2/G6 仿真不适用；产品侧证据，不是 Core 验收或独立采用 |
| Bridge 召回面 | 对 `4bcb39c2`（2026-11-21）的 `cmd/praxo-bridge` 与 `cmd/praxo-bridge/internal/bridge` 源码审计：`run` 与 `event stream` 将请求 prompt 直接传给 `agent.Run`；未发现记忆构造、召回注入、system 角色提升或会话消息存储，`tool list` 返回空列表 | 契约/源码审计 | 仅源码审计；没有 live provider 或端到端 Bridge 记忆测试；不证明未来变更、其他工具或 provider 侧行为中不存在 |
| 集成恢复 | 真实本地 Symbivela、Ontovela、Rheovela、Orchadyn、Praxovela、LIMENORA 和 integration-domain；8 步、5 产品、4 gates、13 证据、11/11 报告检查；preserve/verify 拒绝和 silent-rerun 拒绝 | 本地集成 | 可丢弃本地数据库和固定 ID；没有生产、网络分区、并发负载、独立复现或部署验证 |
| 产品效果账本 | RHEOVELA effect/durable/crash 和 PRAXOVELA tenant-scoped effect-ledger 测试，含内存/SQLite 生命周期与对账 | 契约/单元（产品仓） | 进程内 SQLite/temp 文件；不是 live PostgreSQL 集群或跨服务事务 |
