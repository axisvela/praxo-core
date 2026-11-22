# 示例目录

先按任务选择示例，再按语言查找。Go 参考示例和跨语言示例位于仓库
[`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples)
目录；语言专属示例位于 `language/<language>/examples/`，会进入对应语言的
发现镜像仓库。十三个主题、三十一种语言的覆盖矩阵见
[语言覆盖矩阵](language-coverage.md)。

## 深度与证据

新增领域应用教程位于 `language/<language>/Tutorial/`，与 `examples/` 并列。
场景地图、当前状态和交付标准见 [Tutorial 整体规划](tutorial-plan.md)。目前有
[Python 订单审阅](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review)
和 [TypeScript 订单支持](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review)，
共同调用公开 [agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services)
中的本地合成业务服务。这些是初始确定性切片，
不是完整企业 Web 应用。已有示例与发布文档 URL 保持不变。
教学后端已作为 MIT 源码公开，可本地运行；没有托管业务端点，原演示仓库保持私有。
[Java 订单审阅教程](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review)
另有 loopback HTTP 入口和 JUnit 契约 fixture；本地运行受 JVM 启动器阻塞，Linux CI
已在 `3c2063f9` 通过编译及 mock Agent/Web 测试，见
[run 45031868787](https://github.com/axisvela/praxo-core/actions/runs/45031868787)。
上述历史运行中的私有业务服务集成任务被跳过，不是通过。当前集成任务已固定引用公开
后端提交，不需要私有凭据；三个原生 CLI 客户端已在 `8b0593bb` 的
[run 45033109188](https://github.com/axisvela/praxo-core/actions/runs/45033109188)
对真实本地教学后端通过，使用发布包与确定性模型，不是真实 Provider 验证。

[C# 订单服务台](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review)
新增 ASP.NET Core minimal API 与原生 Core CLI，本地自测及 Web 对真实订单服务路径已通过。
四语言 CLI 与 C# Web 集成已在 Core `ae953050`、公开后端 `cd08b09` 的
[run 45034303513](https://github.com/axisvela/praxo-core/actions/runs/45034303513)
通过。这是确定性教学集成，不是生产身份或真实模型证据。

[PowerShell Windows 诊断教程](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics)
是第一条运维形态路径：fixture 与本机只读服务/磁盘检查，包含策略拒绝和依赖失败。
它通过 `praxo-core-ps` 复用共享 C# Core，不执行修复、远程命令或真实模型。本地
Windows PowerShell 7.7.0 本地测试 4/4 通过；托管 Windows CI 也已在 `5afe6e35` 通过
C# Core 构建和全部四项源码模式检查，见
[run 45036962205](https://github.com/axisvela/praxo-core/actions/runs/45036962205)。

[Perl 日志巡检教程](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage)
增加原生 Perl 运维路径：固定 fixture 日志、严重级别统计和结构化报告，包含策略拒绝与
依赖失败检查。它不读取任意路径、不执行 Shell 命令、不发送告警、不调用真实模型。
本地 Perl 5.40.3 测试通过，Linux CI 也已在 `3b5edcc7` 的
[run 45038008192](https://github.com/axisvela/praxo-core/actions/runs/45038008192) 通过。

[R 数据质量教程](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality)
增加分析路径：固定数据框、原生 R 统计和结构化报告，报告只封装工具计算值。包含策略
拒绝与依赖失败检查。它不读取任意文件、不执行 SQL/Shell、不安装包、不调用真实模型。
本地 R 4.6.1 测试通过，Linux CI 也已在 `e89c9037` 的
[run 45039622807](https://github.com/axisvela/praxo-core/actions/runs/45039622807) 通过。

[COBOL 批处理异常审阅教程](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review)
复用现有确定性批处理交接 fixture，检查独立 COBOL 审阅 worker、worker 不可用和超时三种
路径，并要求批输出与异常文件保持不变。它不实现真实记账、支付、持久队列或恢复证明。
本地 GnuCOBOL 2.0.0 与 Python 3.14 检查通过，Linux CI 也已在 `01d9b1ff` 的
[run 45040372057](https://github.com/axisvela/praxo-core/actions/runs/45040372057) 通过。

[Julia 实验比较教程](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison)
通过原生 Julia Core 计算固定 baseline/candidate 均值与差值，再把计算证据封装进报告。
包含策略拒绝与依赖失败检查。它不读取任意数据、不执行模型提供的 Julia 代码、不安装包、
不调用真实模型。本地 Julia 1.13.2 测试通过，Linux CI 也已在 `bbf12c42` 的
[run 45041423996](https://github.com/axisvela/praxo-core/actions/runs/45041423996) 通过。

[Octave/MATLAB 信号趋势教程](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends)
通过共享 MATLAB/Octave Core 计算固定信号的均值、峰峰值、RMS 与阈值异常，再把计算
证据封装进报告。包含策略拒绝与依赖失败检查。它不读取任意文件、不执行模型提供的代码、
不控制设备、不调用真实模型。本地 GNU Octave 11.3.0 测试通过；原生 MATLAB 未验证。Linux CI 也已在 `0664a194`
的 [run 45042266323](https://github.com/axisvela/praxo-core/actions/runs/45042266323) 通过。

[Python 办公问答教程](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa)
用文档引用回答固定办公政策问题。受限搜索工具返回证据，确定性模型封装顶部结果为答案。
包含策略拒绝与索引失败检查。它不读取任意文件、不调用 Connector、不发送邮件、不调用
真实模型。本地 Python 3.14 检查通过，Linux CI 也已在 `cfd850a6` 的
[run 45043537084](https://github.com/axisvela/praxo-core/actions/runs/45043537084) 通过。

[TypeScript 客服教程](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support)
通过原生 Core 工具读取固定订单与公开运输政策，并用 SSE 流式输出带引用的客服回复。
包含缺少凭据、策略拒绝与依赖失败检查。它不发送回复、不修改订单、不退款、不读取任意
文件、不调用真实模型。本地 Node 24 检查通过；Linux CI 已配置，结果待确认。

示例目录使用[语言覆盖矩阵](language-coverage.md)中的深度标签：

| 深度 | 含义 |
| --- | --- |
| 机制检查 | 孤立的 Schema、Handler、重试或回调断言；可能不调用 Core |
| Core 集成 | 真正调用 Core 的模型、工具、策略、Checkpoint 或事件接口 |
| 应用教程 | 记录设置、输入到输出任务、失败处理和续跑 |

运行记录是独立维度：必须注明 revision、工具链、命令、输出和限制。源码入口不等于
可运行路径。机制检查主题与实际运行记录见[验证证据](../project/verification-evidence.md)。

## 按任务选择

| 任务 | 示例 | 说明 |
| --- | --- | --- |
| 连接真实模型 | [真实模型 Golden Path](live-model-golden-path.md) | 发布包、OpenAI-compatible 端点、一个 `get_time` 工具 |
| 连接其他 Provider 或 MCP | [Provider 与 MCP 演练](../guides/provider-walkthrough.md)、[MCP 教程](../guides/mcp-tutorial.md) | 发布包 Adapter、本地 MCP 客户端与 Transport 边界 |
| 托管 MCP 工具 | [`language/python/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/mcp), [`language/typescript/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/mcp), [`language/csharp/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/mcp), [`language/rust/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/mcp), [`language/java/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/mcp), [`language/ruby/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/mcp), [`language/php/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/mcp), [`language/elixir/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/mcp), [`language/erlang/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/mcp), [`language/lua/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/mcp), [`language/r/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/mcp), [`language/c/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/mcp), [`language/cpp/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/mcp), [`language/fortran/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/mcp), [`language/cobol/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/mcp) | 进程内或 stdio MCP 客户端；确定性工具发现与调用 |
| 增加 Provider fallback | [`language/python/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/provider-fallback)、[`language/typescript/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/provider-fallback)、[`language/csharp/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/provider-fallback)、[`language/rust/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/provider-fallback), [`language/ruby/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/provider-fallback), [`language/php/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/provider-fallback), [`language/c/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/provider-fallback), [`language/cpp/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/provider-fallback), [`language/fortran/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/provider-fallback), [`language/elixir/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/provider-fallback), [`language/erlang/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/provider-fallback), [`language/lua/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/provider-fallback), [`language/r/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/provider-fallback), [`language/cobol/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/provider-fallback), [`language/java/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/provider-fallback) | 主模型失败后切换备用模型；确定性测试 |
| 重试模型调用 | [`language/python/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/retry), [`language/typescript/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/retry), [`language/csharp/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/retry), [`language/rust/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/retry), [`language/java/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/retry), [`language/ruby/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/retry), [`language/php/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/retry), [`language/c/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/retry), [`language/cpp/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/retry), [`language/fortran/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/retry), [`language/elixir/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/retry), [`language/erlang/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/retry), [`language/lua/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/retry), [`language/r/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/retry), [`language/cobol/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/retry) | 有界限的模型中间件仅重试可重试错误，并保留耗尽后的失败 |
| 观察 Agent 事件 | [`language/python/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/event-sink), [`language/typescript/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/event-sink), [`language/csharp/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/event-sink), [`language/rust/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/event-sink), [`language/java/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/event-sink), [`language/ruby/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/event-sink), [`language/php/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/event-sink), [`language/c/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/event-sink), [`language/cpp/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/event-sink), [`language/fortran/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/event-sink), [`language/elixir/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/event-sink), [`language/erlang/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/event-sink), [`language/lua/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/event-sink), [`language/r/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/event-sink), [`language/cobol/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/event-sink) | `run.started`、`tool.call`、`run.completed` 以及 `FilterSink`；确定性测试 |
| 流式输出 | [`language/python/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/streaming), [`language/typescript/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/streaming), [`language/csharp/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/streaming), [`language/rust/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/streaming), [`language/ruby/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/streaming), [`language/php/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/streaming), [`language/c/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/streaming), [`language/cpp/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/streaming), [`language/fortran/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/streaming), [`language/elixir/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/streaming), [`language/erlang/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/streaming), [`language/lua/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/streaming), [`language/r/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/streaming), [`language/cobol/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/streaming), [`language/java/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/streaming) | Delta 回调可重建最终输出；确定性 fake streaming model 测试 |
| 验证安装与拒绝路径 | [消费者 Starter](index.md) | 发布包安装与确定性 allow/deny 检查 |
| 生成受校验 JSON | [结构化输出教程](../guides/structured-output-tutorial.md) | 三十一种语言的确定性 schema 接受/拒绝检查；Python、TypeScript、Java、C# 和 Rust 提供发布包路径 |
| 批量处理为受校验 JSON，含失败与续跑 | [Python 结构化输出应用](../guides/python-structured-output-app.md) | 应用形态 Python 路径，包含输入、结果和错误文件；支持 fixture 与真实模型模式 |
| 校验结构化输出 | [`language/python/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output), [`language/typescript/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/structured-output), [`language/csharp/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/structured-output), [`language/rust/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/structured-output), [`language/java/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/structured-output), [`language/ruby/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/structured-output), [`language/php/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/structured-output), [`language/c/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/structured-output), [`language/cpp/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/structured-output), [`language/fortran/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/structured-output), [`language/elixir/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/structured-output), [`language/erlang/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/structured-output), [`language/lua/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/structured-output), [`language/r/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/structured-output), [`language/cobol/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/structured-output) | JSON Schema 校验；接受合法输出并拒绝非法输出 |
| 构建 Workspace Agent | [Workspace Agent 教程](../guides/workspace-agent-tutorial.md) | 使用发布包的只读 Go 应用 |
| 只读诊断 Windows 服务与磁盘 | [PowerShell Windows 诊断](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics) | 共享 C# Core 上的固定只读工具；不修复、不访问远程主机、不执行任意 Shell |
| 巡检合成日志并生成报告 | [Perl 日志巡检](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage) | 原生 Perl Core、固定 fixture 日志、严重级别统计、拒绝与依赖失败检查 |
| 用计算证据评估数据质量 | [R 数据质量](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality) | 原生 R 统计固定数据框；模型封装工具计算值，不编造数字 |
| 审阅银行批处理异常交接 | [COBOL 批处理异常审阅](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review) | 复用确定性 COBOL 批处理 fixture；独立审阅 worker、不可用和超时路径；无真实记账 |
| 比较固定实验结果 | [Julia 实验比较](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison) | 原生 Julia 对固定结果计算均值/差值；模型封装计算证据，不执行任意代码或作因果结论 |
| 审阅信号趋势与阈值异常 | [Octave/MATLAB 信号趋势](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends) | 原生信号指标计算固定信号；Octave 已验证，不声称原生 MATLAB；无设备控制 |
| 用引用回答办公政策问题 | [Python 办公问答](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa) | 原生 Core、固定文档 fixture、带引用答案、受限拒绝与索引失败 |
| 流式输出带引用的客服回复 | [TypeScript 客服](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support) | 原生 Core、固定订单/政策工具、SSE delta、鉴权拒绝与依赖失败 |
| 嵌入应用 | [应用嵌入清单](../guides/application-integration-checklist.md) | 只读、有副作用、高风险部署的分档清单 |
| 通过 HTTP 运行 Core | [HTTP 嵌入服务教程](../guides/embedded-service-tutorial.md)、[语言覆盖](language-coverage.md) | Go、Python、TypeScript、Java、C# 和 Rust 提供可执行 HTTP 服务；其余已声明语言提供传输中立 Handler 示例 |
| 查看 Go 参考应用 | [`examples/reference`](https://github.com/axisvela/praxo-core/tree/main/examples/reference) | Go 参考应用 |
| 增加 Policy 与审批 | [`examples/governed-workspace`](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace) | Go 受治理执行边界示例 |
| 执行身份与策略校验 | [身份与策略](../guides/identity-policy.md)、[语言覆盖](language-coverage.md) | 全部 31 种已声明语言的可信 principal 绑定、模型声明拒绝与效果前拒绝 |
| 增加 Checkpoint | [`examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/examples/checkpoint) | Go Checkpoint 存储示例 |
| 持久化 Checkpoint | [`language/python/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/checkpoint), [`language/typescript/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/checkpoint), [`language/csharp/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/checkpoint), [`language/rust/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/checkpoint), [`language/java/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/checkpoint)、[`language/ruby/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/checkpoint)、[`language/php/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/checkpoint), [`language/c/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/checkpoint), [`language/cpp/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/checkpoint), [`language/fortran/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/checkpoint), [`language/elixir/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/checkpoint), [`language/erlang/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/checkpoint), [`language/lua/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/checkpoint), [`language/r/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/checkpoint), [`language/cobol/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/checkpoint) | 应用自有存储与 Allowlist 负载；最新记录往返和未注册类型拒绝 |
| 增加 Plugin | [`examples/plugin`](https://github.com/axisvela/praxo-core/tree/main/examples/plugin) | Go 进程/WASM Plugin Host 示例 |
| 委派任务 | [`examples/multiagent`](https://github.com/axisvela/praxo-core/tree/main/examples/multiagent) | Go 本地委派示例 |
| 运行代表性链路 | [`examples/representative-chain`](https://github.com/axisvela/praxo-core/tree/main/examples/representative-chain)、Python [`language/python/examples/representative-chain`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/representative-chain)、TypeScript [`language/typescript/examples/representative-chain`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/representative-chain) | Go 真实模型链路，以及覆盖 MCP、最终授权、委派、OTel/Harmovela 与拒绝零效果的 Python/TypeScript 确定性对应链路 |
| 使用专题配方 | [`examples/recipes`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes) | Go Provider、事件、重试、VFS 等配方 |
| 集成生态组件 | [`examples/ecosystem`](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem) | 可选 AxisVela Adapter 结构 |

## 示例与配方

- [`examples/recipes`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes)
  是 Go 为主的复制粘贴配方，并提供局部测试证据。
- `examples/` 是可运行项目，包括发布包和语言专属集成。

结构化输出、Checkpoint 存储、身份、VFS 隔离和长时操作等主题会同时出现在两种形式中。
配方用于理解机制，示例用于应用形态集成；不要把两者同时复制进一个项目。

## 按语言选择

| 语言 | 示例 |
| --- | --- |
| Go | [`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples) |
| Python | [`language/python/examples`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples) |
| TypeScript | [`language/typescript/examples`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples) |
| Java | [`language/java/examples`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples) |
| C# | [`language/csharp/examples`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples) |
| Rust | [`language/rust/examples`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples) |
| Ruby | [`language/ruby/examples`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples) |
| PHP | [`language/php/examples`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples) |
| C | [`language/c/examples`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples) |
| C++ | [`language/cpp/examples`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples) |
| Fortran | [`language/fortran/examples`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples) |
| Erlang | [`language/erlang/examples`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples) |
| R | [`language/r/examples`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples) |
| COBOL | [`language/cobol/examples`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples) |
| Elixir | [`language/elixir/examples`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples) |
| Lua | [`language/lua/examples`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples) |

每个语言示例目录都有自己的 README，包含安装和运行命令。每个 Core 语言都包含
`consumer`、`live-model`、`hitl` 与 `session-checkpoint` 入口。每语言矩阵见[语言覆盖矩阵](language-coverage.md)。
Python、TypeScript、Java、Rust、C# 等 Core 实现独立版本化；当前支持范围见
[语言总表](../languages/matrix.md)。应用级委派等高级示例见
[高级示例](../guides/advanced-examples.md)。

每个分组内部深度不同。基础示例通常是带确定性检查的 Core 集成；集成示例混合 Core
集成与机制检查；加固和高级示例通常是 Go 应用形态配方或教程，除非对应语言 README
另有说明。不要仅凭任务标签假设同等深度。

## 组织方式

- `examples/` 放置 Go 参考示例和跨语言集成。
- `language/<language>/examples/` 放置语言专属可运行示例。
- 语言示例会复制到对应发现镜像仓库。
- 使用已发布包的示例不要求检出仓库或替换本地包。

示例不是生产安全 Profile。身份、持久审批、效果对账和隔离仍由应用负责。
