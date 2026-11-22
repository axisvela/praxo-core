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
| COBOL 批处理异常审阅 | 复用确定性批处理交接；独立审阅 worker | 本地 GnuCOBOL 2.0.0/Python 检查；Linux CI 已配置待确认 | 无真实记账、持久队列、恢复证明或真实模型 |
| Julia、Octave、Lua、Rust、Zig、C、C++ | 尚未实现为 Tutorial | 未运行 | 仅为候选路径 |

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

1. 增加 Julia 实验比较，作为第二条把计算证据与模型叙述分开的分析路径。
2. 只有存在具体运行时与 transport 契约时才增加设备教程。
3. 把已验证教程转成消费者授权测试路径，而不只是维护者演示。

语言数量不是目标。少量完整、差异化路径比大量孤立机制检查更有价值。
