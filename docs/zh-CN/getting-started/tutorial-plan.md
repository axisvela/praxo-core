# Tutorial 整体规划

**状态：** 公开规划参考，2026-11-22。本页是应用形态 Tutorial 的唯一公开入口，
不是发布排期，也不承诺每种语言都有全部教程。

目标不是把十三个机制主题复制到所有语言，而是展示 **Agent 为什么属于该语言生态**：
Web 服务、运维 Shell、分析工作流、宿主嵌入或受约束设备。每条教程保留一条连贯应用
路径和少量关键边界。

## 规划位置

| 层级 | 位置 | 用途 |
| --- | --- | --- |
| 公开方向 | 本页与[路线图](../project/roadmap.md) | 场景地图、状态、边界与链接 |
| 各语言入口 | `language/<language>/Tutorial/README.md` | 该语言能构建什么、如何运行 |
| 执行细节 | 内部 `PRAXOVELA-EE/docs/praxo-core/planning/shared-business-tutorials.md` | 顺序、验收、运行记录、人员/产品事项 |
| 共享业务 API | [agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services) | 合成契约、fixture、本地服务测试 |
| 证据 | [验证证据](../project/verification-evidence.md) | 准确 revision、范围和限制 |

`Tutorial/` 与 `examples/` 并列；已有机制示例保留原路径。业务 API 不进入 Core 或
`spec/`，它们是教学契约，不是框架兼容性承诺。

## 场景地图

| 语言 / 生态 | 教程成果 | 差异化价值 | 共享后端 |
| --- | --- | --- | --- |
| Java | 订单异常审阅 | 企业 Web 入口、JUnit、发布 Maven Core | 订单 |
| Python | 入职清单与工单草稿 | Retriever/结构化输出与应用服务形态 | 入职（计划） |
| TypeScript | 客户支持流式回复 | 前端/Node 集成与 SSE | 订单 |
| C# | 员工或订单服务台 | ASP.NET Core、可接 OIDC 的服务边界 | 订单；HR 计划 |
| Go | 事件处置协调 | 参考 Core、插件、遥测、长时操作 | 运维（计划） |
| PowerShell | Windows 服务/磁盘诊断 | 固定只读原生运维、本机检查 | 无（本地诊断） |
| Perl | 日志与批处理巡检 | 原生文本处理与既有自动化 | 运维（计划） |
| COBOL | 银行批处理异常审阅 | 确定性批处理与人工复核边界 | 现有批处理 fixture |
| Fortran | 仿真结果诊断 | 数值证据先于模型解释 | 分析（计划） |
| Julia | 实验比较 | 原生数值工作与实验草稿 | 分析（计划） |
| R | 数据质量与统计报告 | 原生统计与附证据叙述 | 分析（计划） |
| Octave / MATLAB | 信号与传感器趋势审阅 | 原生矩阵/信号处理；Octave 与 MATLAB 证据分开 | 分析（计划） |
| Lua | 嵌入既有宿主 | 宿主回调与小体积集成 | 宿主相关 |
| Rust | IoT 网关诊断 | 边缘部署、HTTP 模型 Adapter、进程插件 | 设备（计划） |
| Zig | 小型网关健康检查 | 最小部署与明确平台限制 | 设备（计划） |
| C | 受约束宿主诊断组件 | 调用方负责内存/网络/transport 契约 | 设备（计划） |
| C++ | 工业边缘维护 | 既有设备 SDK 包装为受限工具 | 设备（计划） |

这些是候选路径。只有具备可运行命令、测试和记录证据的教程，才从候选变为已实现。

## 扩展场景目录

下表扩展应用场景，但不承诺全部实现。按运行时契合度、现有工具和具名消费者选择主语言；
教程边界保持狭窄。

| 场景 | 主语言/生态 | 选择理由 | 状态 |
| --- | --- | --- | --- |
| 知识问答与文档助手 | Python、TypeScript | 检索、引用、结构化回答、流式 UI | Python 办公问答已实现并通过 CI |
| 客服与联络中心 | TypeScript、C# | Web/SSE、ASP.NET Core、身份与审计 | TypeScript 客服已实现；CI 待确认 |
| 营销内容与分群 | Python、R | 内容工作流与原生统计分群 | 计划 |
| 办公效率 | Python、C# | 文档、邮件/日历工具、.NET 集成 | Python 办公问答已实现 |
| 销售 / CRM | C#、TypeScript | 企业认证与 Web 集成 | 计划 |
| 理财 / 零售金融 | Java、R | 服务边界与风险/收益分析 | 计划 |
| 保险理赔 | Python、Java | 文档提取、审批与审计边界 | 计划 |
| 采购 / ERP | Java、C# | 企业系统与应用自有身份 | 计划 |
| 工厂 / 制造 | C++、Rust | OPC UA/设备 SDK 接缝与边缘部署 | 计划 |
| 工业自动化 | C++、Rust、Octave | 设备 SDK 与信号分析 | 计划 |
| 消费电子 | Lua、C、Rust | 宿主嵌入、受约束运行时、网关 | 计划 |
| 机器人 | C++、Rust、Julia | ROS 2 集成、控制与数值分析 | 计划 |
| 物流 | Go、Java | 事件驱动服务与长时操作 | 计划 |
| 能源 / 电网 | Rust、C++、Julia | 边缘约束与数值分析 | 计划 |
| 安全 / SOC | Go、Perl、PowerShell | 服务、日志与 Windows 运维 | 计划 |
| 医疗排班 | C#、Java | 身份、审计与企业集成 | 计划 |
| 法律 / 合规 | Python、R | 引用、证据与人工复核边界 | 计划 |
| 教育 / 辅导 | TypeScript、Python | Web 问答与内容工作流 | 计划 |
| 媒体 / 内容 | TypeScript、Python | 流式、生成与发布工具 | 计划 |
| 旅行 / 预订 | TypeScript、C# | Web 入口与企业预订边界 | 计划 |
| 零售 / 电商 | TypeScript、Java | Web 店面与订单服务 | 计划 |
| 数据平台 | Python、R、Julia | 原生计算与附证据报告 | 计划 |

这是需求地图，不是交付承诺。只有具名消费者或维护者、具体任务、确定性模式、拒绝或失败
路径和记录证据齐备时，场景才进入实现。一种语言可以承担多个场景，但首个实现应复用已有
Core 与 Adapter，而不是增加框架表面积。

### 场景选择规则

- 按任务的运行时与库契合度选择语言，而不是按现有示例数量。
- 优先一个本地确定性任务和一两个工具，而不是宽泛的平台模拟。
- 业务契约与合成数据留在 Core 和 `spec/` 之外。
- 身份、持久状态、效果对账与审批由应用负责。
- 消费者未证明可复用缺口前，不新增 Core API。
- 教程通过只是集成证据，不是采用或生产就绪。

## 当前状态

| 教程 | Core 集成 | 验证 | 限制 |
| --- | --- | --- | --- |
| Python 订单审阅 | 原生 Core、HTTP 工具、固定订单范围、仅草稿 | 本地与托管 CI 对公开本地服务 | 确定性模型；无真实 Provider 或外部消费者 |
| TypeScript 订单支持 | 原生 Core、HTTP 工具、固定订单范围 | 本地与托管 CI 对公开本地服务 | 确定性模型；CLI，不是 Web 前端 |
| Java 订单审阅 | 原生 Core、JUnit、loopback Web、真实服务 CLI | Mock/Web JUnit 与真实服务 CLI 已在 Linux CI 通过 | Java Web 对真实后端与真实模型未验证 |
| C# 订单服务台 | ASP.NET Core、原生 Core、CLI 与 Web | 自测及真实服务 CLI/Web 已在 Linux CI 通过 | 确定性模型；无生产身份 |
| PowerShell Windows 诊断 | 通过模块复用共享 C# Core | 本地 Windows 测试与托管 Windows CI | 无 Gallery 安装、修复、远程主机或真实模型 |
| Perl 日志巡检 | 原生 Perl Core、固定 fixture 日志、严重级别报告 | 本地 Perl 5.40.3 测试与 Linux CI | 无任意路径、Shell、告警发送或真实模型 |
| R 数据质量 | 原生 R 统计、固定数据框、计算报告 | 本地 R 4.6.1 测试与 Linux CI | 无任意文件/SQL/Shell、真实模型或因果结论 |
| COBOL 批处理异常审阅 | 复用确定性批处理交接；独立审阅 worker | 本地 GnuCOBOL 2.0.0/Python 检查与 Linux CI | 无真实记账、持久队列、恢复证明或真实模型 |
| Julia 实验比较 | 原生 Julia 对固定结果计算均值/差值 | 本地 Julia 1.13.2 测试与 Linux CI | 无任意数据/代码/包安装、真实模型或因果结论 |
| Octave/MATLAB 信号趋势 | 共享信号指标、阈值异常 | 本地 GNU Octave 11.3.0 测试与 Linux CI | 原生 MATLAB 未验证；无设备控制或真实模型 |
| Python 办公问答 | 原生 Core、固定文档、带引用答案 | 本地 Python 3.14 检查与 Linux CI | 无任意文件/Connector、邮件操作或真实模型 |
| TypeScript 客服 | 原生 Core、固定订单/政策工具、SSE 流 | 本地 Node 24 检查；Linux CI 已配置待确认 | 无回复发送、订单修改、退款或真实模型 |
| Lua、Rust、Zig、C、C++ | 尚未实现为 Tutorial | 未运行 | 仅为候选路径 |

准确运行 ID 与范围见[验证证据](../project/verification-evidence.md)。“CI 通过”不等于
生产就绪、独立采用或公共托管业务服务。

## 共享业务服务

维护中的教学后端是公开 MIT 源码
[agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services)。
它在 loopback 本地运行，没有托管端点。Python、TypeScript、Java 和 C# 订单教程共享
其合成订单契约，但各自保留 Core、工具、Policy 和模型 Adapter。

原 `demo-repository` 保持私有。Core CI 固定引用公开后端提交，不需要私有 token。
业务服务代码不得复制进 Core 或 `spec/`。

## Tutorial 交付标准

每条已实现教程应提供：

1. 明确任务与非目标；
2. 无需 Provider 凭据或公共服务即可运行的确定性模式；
3. 复用同一业务工具的可选真实模型模式；
4. 至少一条拒绝或依赖失败路径，且无意外效果；
5. 身份、持久化、审批与效果对账由应用负责的边界；
6. 准确运行命令、预期输出和非零失败行为；
7. CI 可执行的测试入口；
8. 范围声明：源码、本地、CI、真实本地服务、真实 Provider、独立复现分别记录。

教程不应新增 Core 或 wire API，除非具名消费者证明存在可复用缺口。应用专属工具属于
教程，不属于 `pkg/...` 或 `spec/`。

## 下一步

1. 只有存在具体消费者路径后，才增加 Java 理财/金融或 C# 销售/CRM。
2. 只有存在具体运行时与 transport 契约时才增加设备教程。
3. 把已验证教程转成消费者授权测试路径，而不只是维护者演示。

语言数量不是目标。少量完整、差异化路径比大量孤立机制检查更有价值。
