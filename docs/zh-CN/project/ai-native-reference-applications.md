# AI-Native 参考应用设计

**状态：** 设计于 2026-11-25 采纳，证据于 2026-11-26 审核。源码实现不等于完整宿主集成验收。PHP v1 harness 已在
`language/php/application/ai-editorial-studio` 本地实现；同级 `content-review`
应用仍是宿主集成前驱。Java v1 源码已添加到 `language/java/application`，使用 Spring Boot
和已发布 Core 0.12.1，但本地 Windows JVM 阻塞，因此 Java 尚未本地编译或测试。
Elixir v1 harness 已在 `language/elixir/application` 本地实现：监督树中的遥测存储与修复
执行器，源码模式测试 6/6 通过，包含租户拒绝与监督进程重启；结果记录模型
diagnosis/rationale 与 `agent_trace`。本地 Hex 安装遇到 unknown-CA 失败，因此 CI
使用已发布包且已添加但未运行。Erlang v1 已在 `language/erlang/application` 实现：源码模式
6/6 通过（含监督进程重启），真实运行记录模型 diagnosis/rationale 与 `agent_trace`。
Go v1 已在 `language/go/application` 实现：HTTP/CLI 宿主，使用本地 module replace 而非 registry 安装；8/8 测试通过，真实运行记录
模型选择的工具、diagnosis/rationale 与 `agent_trace`。Rust v1 已在
`language/rust/application` 实现：边缘 CLI 与 `GatewayAdapter`，使用本地 Core path 依赖而非 registry 安装；6/6 测试通过，托管
DeepSeek 真实运行通过应用自有 `curl` transport 记录 `model=live`、模型选择工具、只读草案和
`executions=0`。C++ v1 已在 `language/cpp/application` 实现为源码/静态库集成；由于 SEP
拦截可执行产物，本仓库不生成 exe，live transport 仅为源码，未记录 C++ 运行或真实模型证据。
COBOL v1 已在
`language/cobol/application` 实现：原生 `praxo-run` harness 五项确定性检查加批处理文件检查
通过，但未捆绑 live model transport。Julia v1 已在 `language/julia/application` 实现：
原生 `LinearAlgebra` 响应面 harness 六项确定性检查通过，托管 DeepSeek
`deepseek-flash` 真实运行记录 `model=live`、模型选择工具、计算拟合证据与 `writes=0`。
Ruby v1 已在 `language/ruby/application` 实现：Rails 8 宿主通过五项确定性检查，托管
DeepSeek `deepseek-flash` 真实运行记录 `model=live`、模型选择工具、只读订单草案和零支付/
退款效果。PHP、Elixir、Erlang、Go、Rust、Julia、Ruby 已使用托管 DeepSeek
`deepseek-flash` 记录真实模型推理运行；Java/C++/COBOL 真实推理、SDK CI、Drupal、支付和
独立消费者路径仍未关闭。其他语言以直接实现 AI-native 流程为目标。

两个 PHP 应用作业于 2026-11-25 在
[45655799714](https://github.com/axisvela/praxo-core/actions/runs/45655799714)、
`92ba764c` 通过；该运行因 C++ 配置失败而整体失败，其他应用作业被跳过。
后续 [45720963270](https://github.com/axisvela/praxo-core/actions/runs/45720963270)、
`f8242fb3` 仅通过 C++ 静态库构建，其他应用作业全部跳过。Java 仍未验证，C++ 无运行时/真实模型证据。
这些是逐作业结果，不是 SDK 全面 CI 或整个组合验收。七个托管参考应用运行不验证 #31
单独跟踪的发布包 starter 托管端点路径。

## 目的

[参考应用组合](roadmap.md)为各语言选择典型工作负载。本设计补充缺失的质量标准：
Agent 必须是产品主流程，而不是传统应用外加一个 AI 审阅接口。

一个 CRUD 门户只加一个“用 AI 审阅”端点，不算合格。AI-native 参考应用应从用户意图或
模型决策开始，检索宿主上下文、选择工具、产出有用草案或工件，并在应用自有的审批或
效果边界停止。

## 判定标准

AI-native 参考应用必须同时满足：

1. 主任务从自然语言或模型决策开始，而不是只能从列表选择既有记录。
2. 应用检索并标记宿主上下文；模型决定下一步和工具调用。
3. 宿主仍是系统记录源；高风险效果由应用负责并受策略门禁。
4. 无需凭据的确定性模式执行同一循环和策略。
5. 真实模型模式复用相同工具和策略，并单独记录。
6. 发布、支付、设备命令等高风险效果必须有应用自有的人工审批边界。
7. 测试覆盖有用结果、副作用前拒绝、依赖失败和无效模型输出。
8. 集成使用宿主真实路由、服务容器、身份、持久化、事件和部署形态。

### 验收问题

去掉模型后，产品的主流程是否消失？

- **是：** AI-native。
- **否：** 只是带可选 AI 功能的传统应用。

### 反模式

- 静态表单，唯一 AI 步骤是总结既有记录。
- 聊天面板能读数据，但在主产品流程之外。
- 模型直接写 CMS、订单系统或设备。
- Demo 只证明工具调用，没有有意义的宿主任务。
- 只有真实模型路径，没有确定性回放。

## 场景地图

Agent 驱动下列主流程；宿主仍是系统记录源，负责人工审批、身份、持久化和效果对账。

| 优先级 | 语言 | AI-native 产品 | 主流程 | 宿主集成 | 治理与效果 |
| --- | --- | --- | --- | --- | --- |
| 1 | PHP | 内容门户/CMS 的 AI 编辑工作室 | 选题 -> 检索既有内容 -> 生成文章、分类与 SEO -> 生成发布审阅 | Laravel 先行；Drupal 模块随后 | 不写 CMS；仅审阅发布；`publications_executed=0` |
| 2 | Java | AI 电商助手 | 自然语言找商品 -> 比较 -> 购物车/结算草案 -> 订单/退款审批 | Spring Boot 电商服务 | 应用事务与远程效果分开；无审批不支付 |
| 3 | Elixir / Erlang | 实时运维 Copilot | 遥测/异常 -> 分诊 -> 修复草案 -> 审批 | OTP 监督与消息系统 | 有界工作、取消/对账、未审批不执行修复 |
| 4 | Go | 基础设施运维 Agent | 告警 -> 诊断 -> allowlist 修复草案 | 既有服务/CLI 与控制面客户端 | 先只读；变更需明确审批 |
| 5 | C++ / Rust | 边缘/设备 Agent | 传感器或遥测 -> 诊断 -> 有界动作草案 | 真实设备 SDK、仿真器或 transport | 命令授权、取消确认、效果验证 |
| 6 | COBOL | 批处理异常分析 Agent | 批处理 -> 异常 -> 分析 -> 审阅交接 | 既有批处理系统 | 不记账；主批输出不变 |
| 7 | Julia | 科学计算 Copilot | 数据/模型 -> 数值分析或优化 -> 附证据报告 | 既有数值栈 | 不控制设备或生产；说明复现限制 |
| 8 | Ruby | 电商/SaaS 助手 | 客户意图 -> 账户/订单工具 -> 草案动作 | Rails 服务、Active Record/Active Job | 不声称外部 exactly-once；审批与效果对账 |

其他典型 AI-native 方向：

| 语言 | AI-native 方向 |
| --- | --- |
| Python | 数据/AI 流水线 Copilot 或 Django/FastAPI 服务助手 |
| TypeScript | 店面或 BFF 流式助手 |
| C# | 企业服务台或业务系统 Copilot |
| Perl | 既有日志/工单分析助手 |
| Lua | 宿主/游戏扩展助手 |
| C | 受约束嵌入式诊断组件 |
| Fortran | 仿真分析助手 |
| R | 统计分析与报告助手 |
| PowerShell | Windows/IT 运维助手 |
| MATLAB/Octave | 信号分析助手 |
| Swift/Kotlin/Scala/Dart | 平台应用或服务助手 |
| Haskell/OCaml | 编译器或静态分析助手 |
| Zig/D/Nim/V | 系统或 CLI 助手 |
| Delphi/Objective-C | 桌面或 Apple 旧有应用助手 |

这些是选型假设，不是市场排名。每个候选都必须通过 AI-native 验收问题和参考应用证据标准。

## PHP v1：AI 编辑工作室

### 产品流程

1. 编辑提交选题、目标栏目和租户。
2. Agent 检索应用自有内容索引中的相关材料。
3. Agent 生成标题、提纲、正文、标签和 SEO 描述。
4. Agent 创建仅审阅的发布请求。
5. 编辑在宿主应用中批准、编辑或拒绝。
6. 应用执行 CMS 效果；Agent 不直接写入。

### 宿主入口

- `POST /api/editorial/drafts`，携带选题和已认证租户。
- Artisan 命令 `content:draft-article` 执行同一流程。
- Laravel 路由、中间件、容器绑定、配置和内容索引。
- Drupal 作为下一宿主：把同一流程映射到 CMS 实体、编辑工作流状态和权限。
  不把 Drupal core 放入本 MIT 仓库；模块代码保持 MIT，Drupal 作为外部 GPL 依赖。

### 工具

| 工具 | 效果 | 策略 |
| --- | --- | --- |
| `search_content` | 只读检索宿主索引 | 租户与选题范围；检索内容标记为不可信 |
| `draft_article` | 只生成草案工件 | 不写 CMS；校验输出 schema |
| `suggest_taxonomy` | 建议标签和栏目 | 只读 |
| `request_publish_review` | 创建仅审阅请求 | 必须经过审批边界；不发布 |
| `publish_article` | 会写入 CMS | Agent 路径始终拒绝；由独立审批的宿主流程执行 |

### 治理

- 模型不拥有发布权限。
- 策略检查租户、选题范围、工具名，以及编辑后的最终参数。
- “立即发布”类选题在产生任何 CMS 效果前被拒绝。
- 检索内容是不可信数据，不是 system 指令。
- 输出校验通过后才成为审阅项。
- 审批 UI、审计记录和 CMS 写入由应用负责。

### 确定性与真实模型

- 确定性模型执行检索、起草、分类和审阅请求，返回通过 schema 校验的包。
- 真实模型复用相同 schema 和策略。Provider、端点、成本、延迟和失败单独记录。
- 测试不依赖凭据。

### 必需测试

- 有来源、`publications_executed=0` 的有用草案。
- “立即发布”选题在效果前被拒绝。
- 缺失/错误租户在检索前被拒绝。
- 内容索引依赖失败：一次读取后失败且无草案。
- 无效模型输出被拒绝。
- Artisan 路径与 HTTP 流程一致。
- 可选真实模型运行单独记录。

## Java v2 草案

订单/结算场景留给 Java，因为电商是 Java 的典型宿主。AI-native Java 参考应用应：

- 接受自然语言购物意图；
- 检索商品、库存、价格和订单上下文；
- 比较选项并生成购物车或结算草案；
- 在支付和退款审批边界停止；
- 使用 Spring Boot 服务、安全身份传递和事务，同时区分本地事务与远程效果。

没有已批准的宿主路径，不声称支付、退款或库存写入。

## 跨语言不变量

- Agent 提出建议；应用授权并执行高影响效果。
- 工具由应用拥有且范围狭窄。
- 策略在效果边界和参数编辑后执行。
- 检索或模型生成内容不可信。
- 确定性测试是基线；真实模型是单独证据。
- 参考应用不是新 Core API；应用逻辑留在宿主。
- 源码、宿主运行、真实 Provider、独立复现和持续使用分别记录。

## 推理证据

确定性或脚本模型是测试替身。它们可以证明工具 schema、策略、审批边界、失败处理和
trace 接线，但不能证明大模型推理。

AI-native 推理声明需要一次记录在案的真实模型运行，并展示：

1. 模型根据请求和先前观察选择工具与参数；
2. 宿主工具返回观察；
3. 模型撰写诊断、草案、理由或回答；
4. 策略与审批边界仍然生效；
5. 运行记录模型 ID、端点类型、工具 trace、延迟和成本；
6. 输出或 trace 可检查，且不只是固定 fixture 文本。

当前状态（2026-11-25）：PHP、Elixir、Erlang、Go、Rust、Julia、Ruby 已使用托管 DeepSeek
`deepseek-flash` 记录真实模型推理运行。

- PHP：`model=live`，四步 trace（`search_content` -> `draft_article` ->
  `suggest_taxonomy` -> `request_publish_review`），模型理由（最近一次 858 字符），
  `publications_executed=0`。运行使用自定义 cURL transport 处理本地代理/CA。
- Elixir：`model=live`，模型先选择 `search_signals(service-100)`，再生成包含
  diagnosis/rationale 的 `draft_remediation`，最终 `executions=0`。更早一次尝试把
  展示名 `checkout` 当作 service id，被策略拒绝；把授权 service id 加入提示词后模型
  自行改对。
- Erlang：`model=live`，相同工具序列与模型 diagnosis/rationale，`executions=0`。
  live transport 使用 `httpc` 与本地代理/CA。
- Go：`model=live`，三步 trace（`search_signals` -> `draft_remediation` -> 最终报告），
  350 字符 diagnosis 与 523 字符 rationale，`executions=0`。
- Rust：`model=live`，模型选择 `read_gateway` 再选择 `draft_action`，写入模型生成的
  diagnosis/rationale，最终 `executions=0`。live 路径使用应用自有 `curl` transport，绕过
  本地 `ring`/TLS 构建阻塞。
- C++：源码/静态库集成。SEP 拦截可执行文件，因此确定性路径和 live 路径均未在本地运行，
  未记录 C++ 运行时或真实模型证据。
- COBOL：有原生确定性 harness 和批处理文件检查，但 COBOL Core 未捆绑 HTTP/TLS client，
  因此没有真实运行记录。
- Julia：`model=live`，模型选择 `load_observations` 再选择 `fit_response_surface`；
  报告保留计算得到的二次拟合（R² `0.999995`）、边界内最优 `0.6994`、预测产量
  `0.91764`、`writes=0` 和 `mutating_actions=[]`。Windows transport 使用
  `curl.exe --ssl-no-revoke`。
- Ruby：`model=live`，模型多次选择 `search_catalog`，然后选择 `quote_cart` 和
  `draft_order`。应用返回 `draft_only` 订单、`$105.84` 报价总额、
  `payment_charges=0`、`refunds=0` 和 `mutating_actions=[]`。Windows transport 使用
  `curl.exe --ssl-no-revoke`。

Java 仍仅有源码且未本地编译，没有真实模型运行。确定性 harness 测试是单独证据，不能
替代真实运行。

## 证据标准

| 层级 | 参考应用必须提供 |
| --- | --- |
| 确定性 | HTTP/CLI 成功、效果前拒绝、依赖失败、无效输出 |
| 宿主运行 | 真实框架启动、容器、配置、身份边界与宿主服务 |
| 真实模型 | 可选且单独记录；复用相同工具和策略 |
| 独立 | 外部消费者复现，不是维护者 fixture |
| 持续使用 | 采用后的变更或升级 |

包、宿主、运行时或凭据缺失时标为阻塞，不算通过。

## 从当前基线的迁移

- Laravel 内容审阅应用保留为前驱基线，位于
  `language/php/application/content-review/`。
- AI-native PHP v1 位于 `language/php/application/ai-editorial-studio/`，
  不替换也不改标前驱。
- 两个 PHP 应用都使用已发布 Core 包并有确定性本地测试；两个 PHP CI 作业已在 `45655799714`、`92ba764c` 通过。
- 订单/结算工作移到 Java 电商参考应用。
- 其他语言直接实现 AI-native 流程，不先做传统应用前驱。
- 教程仍是教程；参考应用位于 `language/<language>/application/`。

## 待定决策

1. PHP 先 Laravel 还是先 Drupal。建议：Laravel 先验证宿主管线，Drupal 随后验证 CMS 原生工作流与权限。
2. 内容索引：fixture、SQLite 还是 CMS API。
3. 草案持久化：内存、数据库还是 CMS revision。
4. 审批入口：HTTP 路由、队列还是 CMS 编辑工作流。
5. 真实 Provider 与模型选择。
6. 输出 schema 与校验严格度。
7. 是否存在需要新增 Core API 的可复用缺口。默认不新增。

## 批准后的实施顺序

1. 更新 roadmap 与 tutorial-plan，链接本设计。
2. 实现 PHP AI 编辑工作室及确定性测试。
3. 增加 CI 和可选真实模型命令。
4. 记录证据并更新跟踪 Issue。
5. 开始 Java 电商助手。
6. 增加 Drupal 宿主并记录许可与部署边界。
7. 仅在维护能力和消费者反馈允许时继续后续组合。

## 风险

- 模型输出质量不确定；必须校验 schema 和来源。
- 防止范围蔓延到 CMS 发布；Agent 保持仅审阅。
- Drupal 的 GPL 依赖必须留在 MIT 仓库外。
- 成本和延迟必须测量，不能推断。
- AI-native 声明容易膨胀；必须使用验收问题和证据。
- 检索内容中的提示注入不得获得 system 权限。
