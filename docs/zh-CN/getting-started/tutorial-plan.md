# Tutorial 整体规划

按行业、语言、场景和能力浏览[教程与场景总目录](tutorial-catalog.md)。总目录统一收录
原有主题、100 个候选目标、应用教程、指南、recipes 和机制示例，分别计数。
本页记录交付标准与限定验证，不再重复维护一套库存和各条目的 CI 待运行标签。

**状态：** 公开规划参考，2026-11-25。候选语言/场景分配均已有基础切片。
教程 CI 在 `dfdfd558`、[运行 45537631891](https://github.com/axisvela/praxo-core/actions/runs/45537631891)
通过，取代之前的待运行状态，但不改变本地工具链限制。这不是发布排期、独立采用，
也不承诺全部语言具备全部能力。100 个完整目标仍无已记录的端到端参考应用；
切片按自身有界范围独立验收。

下一阶段优先[参考应用组合](../project/roadmap.md)：PHP、Java、Elixir/Erlang、Go、
C++/Rust、COBOL、Julia、Ruby。复用有用切片，证明宿主生态和运行时集成，而非再次证明
该语言能实现通用 Agent Loop。

## 规划位置

| 层级 | 位置 | 用途 |
| --- | --- | --- |
| 公开方向 | 本页与[路线图](../project/roadmap.md) | 范围、优先级、标准与证据链接 |
| 唯一库存 | [教程总目录](tutorial-catalog.md) | 生成的场景、语言与源码入口 |
| 各语言入口 | `language/<language>/Tutorial/README.md` | 运行时依据、命令和逐教程限制 |
| 参考应用 | `language/<language>/application/README.md` | 宿主集成、安装/运行命令、证据与限制 |
| 执行细节 | 内部 `PRAXOVELA-EE/docs/praxo-core/planning/shared-business-tutorials.md` | 顺序、验收、运行记录和产品事项 |
| 共享业务 API | [agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services) | 合成契约、fixture 和本地服务测试 |
| 证据 | [验证证据](../project/verification-evidence.md) | 准确 revision、范围和限制 |

`Tutorial/` 与 `examples/` 并列。参考应用统一放在
`language/<language>/application/`，不进入生成的教程目录；它们属于完整宿主集成，
不是教程切片。既有机制示例保持发布路径。业务 API 留在 Core 和 `spec/` 之外，
属于教学契约，不是框架兼容性承诺。

## 语言选择门槛 {#language-selection-gate}

[语言适配教程设计](runtime-scenario-design.md)记录 V、D、Haskell、OCaml、Erlang、Julia、
Octave、COBOL 和 Zig 的有界路径。这些可供参考应用复用，不等于完整应用。

基础入口已交付一轮。保留准确、有用的示例，用复现和实际反馈选择深化方向。
基础示例不以具名消费者或已证明的生态优势为发布前提；参考应用则必须实际使用宿主或依赖，
不能由通用回调宣称生态价值。

每个新增或实质修改的教程必须包含 `Why this language and runtime?` 小节，回答：

- **选择依据：** 什么既有宿主、依赖、部署约束或消费者支持保留此运行时？
- **已演示适配：** 哪条可执行代码与测试实际使用该集成，而非未来设想？
- **适用条件：** 什么应用条件下值得参考？
- **不适用条件：** 何时简单工作流、其他运行时或外部编排更合适？
- **证据边界：** Core 集成、已运行的生态集成，还是独立消费者复现？

语言说明描述运行时、并发、类型、工具链、平台或库的权衡，而非只有 Core 接线。
将语言特点与集成说明分开，不编造性能比较或绝对优势。缺少该小节的既有教程仍未完成
运行时适配评估。

固定 JSON、通用回调和脚本模型只证明 Core 集成。编译不证明低延迟、小体积、安全、
形式正确性或受监管场景适用性。既有宿主可解释示例价值，但不证明语言独特优势。
不为填满矩阵复制第二语言，需先有不同宿主、依赖或部署问题与可测试成果。
OTP 需要故障恢复测试，Flutter 需要真实入口，规则语言需要解析/求值和反例，而非预置结论。
这是声明质量门槛，不要求批量深化无人使用的教程。

## 场景地图

[路线图](../project/roadmap.md)规定下一轮宿主集成顺序；现有源码、能力和范围由
[总目录](tutorial-catalog.md)索引。Laravel、Spring Boot、Rails 等参考应用是拟建设路径，
不代表现有 fixture 已完成完整生态应用。优先 PHP，先完成一条连贯路径再扩展。

## 扩展场景目录

[100 个智能体场景](agent-scenarios.md)涵盖十六大领域、稳定 ID 与候选语言。
100 个目标均有相关切片，但完整目标无已记录端到端参考应用，也无普遍跨语言 parity 保证。
原有主题仍作为发现分组，不另建交付 backlog；源码与限定范围以生成目录为准。

| 场景 | 主语言/生态 | 选型问题 |
| --- | --- | --- |
| 知识问答与文档助手 | Python、TypeScript | 检索、引用和结构化回答 |
| 客服与联络中心 | TypeScript、C# | Web/SSE、服务身份和审计 |
| 营销内容与分群 | Python、R | 内容工作流与原生分群统计 |
| 办公效率 | Python、C# | 既有文档或办公宿主 |
| 销售 / CRM | C#、TypeScript | 应用认证与业务 API |
| 理财 / 零售金融 | Java、R | 服务边界和计算风险证据 |
| 保险理赔 | Python、Java | 文档证据与人工复核边界 |
| 采购 / ERP | Java、C# | 既有企业服务与权限 |
| 工厂 / 制造 | C++、Rust | 实际设备 SDK 或边缘 transport |
| 工业自动化 | C++、Rust、Octave | 设备接入与信号分析 |
| 消费电子 | Lua、C、Rust、Zig | 既有宿主和资源限制 |
| 机器人 | C++、Rust、Julia | 仿真器、设备 transport 与数值依赖 |
| 物流 | Go、Java | 事件服务和应用自有恢复 |
| 能源 / 电网 | Rust、C++、Julia | 边缘接入与可执行优化 |
| 安全 / SOC | Go、Perl、PowerShell | 服务、原生日志与 Windows 运维 |
| 医疗排班 | C#、Java | 身份、复核和预约边界 |
| 法律 / 合规 | Python、R | 引用与证据，不是法律结论 |
| 教育 / 辅导 | TypeScript、Python | Web 入口与有界教学内容 |
| 媒体 / 内容 | TypeScript、Python | 流式与明确发布权限 |
| 旅行 / 预订 | TypeScript、C# | 库存、复核和预订效果 |
| 零售 / 电商 | TypeScript、Java | 既有店面与订单 API |
| 数据平台 | Python、R、Julia | 原生计算和附证据报告 |

### 场景选择规则

- 按宿主/运行时、工具与具体任务选型，不按示例数量。
- 基础切片保持有界、确定性、无凭据，并有拒绝或失败测试。
- 业务契约与合成数据留在 Core 和 `spec/` 外。
- 身份、持久状态、审批和效果对账由应用负责。
- 消费者证明可复用缺口前不增加 Core API。
- 教程通过只是集成证据，不是采用或生产就绪。

## 当前状态

统一使用绑定 revision 的快照，不逐条重复 CI 待运行状态。`dfdfd558` 的教程运行
`45537631891` 全部作业通过，包含新 Java、Swift、Objective-C、原生编译语言切片、
语言适配路径与共享服务集成。[固定版本工作流](https://github.com/axisvela/praxo-core/blob/dfdfd55873368c921fed29ad201d20986a935866/.github/workflows/ci-tutorials.yml)
定义命令和 runner；通过不延伸到任意后续 revision。

| 证据 | 当前范围 | 仍有限制 |
| --- | --- | --- |
| 基础场景批次 | 源码入口与 `dfdfd558` 教程 CI 通过 | 不是 100 个完整应用、真实模型或独立消费者 |
| 语言适配路径 | V 预检、D 解析、Haskell 规则、OCaml 诊断、OTP 恢复、Julia 调度、Octave 振动、COBOL 对账和 Zig 预算作业通过 | 有界 fixture，不证明生产可用性、求解器认证或硬件安全 |
| Java、Swift、Objective-C | 对应教程在配置的托管 runner 运行通过 | 本地 Windows JVM/Swift 限制仍在，Apple 证据不延伸至所有源码路径 |
| MATLAB/Octave | 共享教程使用 Octave 执行 | 原生 MATLAB 仍未验证 |
| Delphi / Free Pascal | 教程使用 Free Pascal | 商业 Delphi 仍未验证 |
| 共享订单服务 | Python/TypeScript/Java/C# CLI 与 C# Web 接入 loopback 教学后端 | 确定性模型；不建立 Java Web 对真实后端、生产身份或外部采用 |
| 生态原生参考应用 | PHP 在 `language/php/application/` 下有两个 Laravel 12 路径（前驱 7/7、AI-native 9/9，Core 0.8.1）；托管 DeepSeek `deepseek-flash` 运行记录 `model=live`、四步工具、模型理由和零发布。Elixir AI 运维 Copilot 位于 `language/elixir/application`（OTP 监督，源码模式 6/6）；托管 DeepSeek 运行记录模型选择工具、diagnosis/rationale、`agent_trace` 和零执行。Erlang AI 运维 Copilot 位于 `language/erlang/application`（OTP 监督，源码模式 6/6）；托管 DeepSeek 运行记录相同工具序列、diagnosis/rationale 和零执行。Go AI 基础设施 Agent 位于 `language/go/application`（HTTP/CLI，8/8 测试）；托管 DeepSeek 运行记录模型选择工具、350 字符 diagnosis、523 字符 rationale、`agent_trace` 和零执行。Rust AI 边缘网关 Agent 位于 `language/rust/application`（CLI，`GatewayAdapter`，6/6 测试）；live 被本地 TLS backend 构建阻塞。C++ AI 工业边缘 Agent 位于 `language/cpp/application`（CLI，`GatewayAdapter`，本地五项检查）；live 未实现，因为 Core adapter 需要应用提供 HTTP transport。Java AI 电商源码位于 `language/java/application`（Spring Boot，Core 0.11.0），有 trace/rationale，但无本地编译或真实运行 | PHP 真实运行使用自定义 cURL transport 处理代理/CA；Elixir 本地 Hex 遇到 unknown CA，CI 使用已发布 Hex；Erlang 编译 Core 源码；Go 使用本地 module replace；Rust 使用本地 path 依赖且 TLS 构建阻塞；C++ 使用本地 Core CMake target；Java 本地 JVM 阻塞；PHP/Java/Elixir/Erlang/Go/Rust/C++ CI 已添加但未运行；无 Drupal 宿主、支付、生产身份、独立消费者或生产部署；优先级 6-8 仍为拟建设 |

之前本地记录与 CI 失败保留为历史证据，后续通过不抹去失败。
准确运行和范围见[验证证据](../project/verification-evidence.md)。CI 不证明真实 Provider、
公共托管业务服务、生产就绪或独立采用。

## 共享业务服务

公开 MIT 后端 [agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services)
在 loopback 运行，无托管端点。Python、TypeScript、Java 和 C# 共享合成订单契约，
保留各自原生 Core、工具、策略和模型 Adapter。CI 固定公开后端提交，不需要私有 token。
原 `demo-repository` 保持私有，不将业务服务代码复制进 Core 或 `spec/`。

## Tutorial 交付标准

1. 明确任务、非目标和运行时选型依据。
2. 不需 Provider 凭据或公共服务的确定性模式。
3. 复用相同工具的可选真实模型路径；缺失时明确说明，不暗示已验证。
4. 拒绝或依赖失败检查，无意外副作用。
5. 应用自有身份、持久化、审批和效果对账边界。
6. 准确安装/运行命令、预期输出和非零失败行为。
7. CI 可执行测试入口与固定依赖版本。
8. 源码、本地、CI、真实 Provider、独立复现分别记录。

参考应用额外要求真实宿主入口、有用端到端任务和独立可运行的真实模型路径，
按路线图验收。不为应用专属逻辑扩大 Core 或 wire API。

## 下一步

1. 完成 PHP Laravel 路径：运行已添加的 CI 作业、记录绑定 revision 的结果，并在开始 Java 前争取消费者复现。
2. 使用宿主真实服务、身份和业务边界，分别公开确定性与真实模型命令。
3. 验证拒绝、依赖失败和运行时行为，再获取消费者复现和持续使用证据。
4. 用有界选型基准发现路径阻力，不把基准作为参考应用交付的前置条件。

保留有用基础切片。新增宿主深度用于验证生态价值，不增加语言数量，也不要求重写所有教程。
