# 采用计划

**状态：** `2.1.0` 周期的 90 天计划。

## 目标

让 Go 团队能在十分钟内从发现走到首次成功运行，并在不 fork 框架的情况下完成
生产集成。

## 指标

- 首次成功运行所需时间
- quickstart 成功反馈
- 外部集成方数量
- issue 和 PR 响应时间
- 适配器覆盖（OpenAI 兼容、MCP、AxisVela）
- 文档覆盖率与失效链接数

不要追求 star 等虚荣指标；它们只能作为滞后信号。

## 工作流

### 发布

- 发布 `v2.1.0`，包含适配器与文档能力。
- 单独发布 `adapters/mcp/v0.1.0`。
- 采用每月次要版本节奏和发布检查清单。
- 保持 `pkg/...` 冻结；增量工作放入 adapters、examples 和 docs。

### 试用

- 保持一条命令的 quickstart 可对 Ollama 运行。
- 维护 reference workspace Agent。
- 保持文档站、Recipes 和采用指南最新。
- 为每个可运行示例增加冒烟测试。

### 集成

- OpenAI 兼容与 MCP 适配器。
- NOETIVELA、Mnemovela、GNOSIVELA SDK recipes。
- 评估原生 Anthropic 和 Gemini 适配器。
- 增加 Harmovela、AEGIVELA、LIMENORA、RHEOVELA recipes。

### 证明

- 发布基准方法与回归结果。
- 增加 OpenTelemetry 事件 Sink。
- 有外部集成方后发布生产案例。
- 保持安全模型和兼容性门禁最新。

### 社区

- 保持 issue/PR 模板可操作。
- 标注并维护 good first issues。
- 使用 Discussions 讨论设计问题。
- 每月发布简短路线图更新。

## 30 / 60 / 90 天

### 第 0-30 天

- 发布 `v2.1.0` 和 `adapters/mcp/v0.1.0`。
- 发布 launch 文章和 GitHub release notes。
- 创建五个 good first issues。
- 收集 quickstart 反馈，修复前三个阻塞问题。
- 增加文档分析或轻量反馈入口。

### 第 31-60 天

- 评估原生 Anthropic 和 Gemini 适配器。
- 增加 MCP resources、prompts 和流式进度。
- 增加 OpenTelemetry 事件 Sink。
- 发布 Harmovela、AEGIVELA、LIMENORA recipes。
- 创建案例模板。

### 第 61-90 天

- 发布 `v2.2.0`，包含价值最高的 provider/protocol 能力。
- 发布可复现的基准说明。
- 发布一个外部案例或集成故事。
- 举办社区路线图讨论。
- 启动社区维护的适配器索引。

## 推广渠道

- GitHub release 和 Discussions
- Go Weekly 和 Golang Weekly
- Reddit r/golang
- Hacker News Show HN
- X 和 LinkedIn
- AxisVela 产品渠道

## 内容日历

| 周 | 内容 |
| --- | --- |
| 1 | 10 分钟构建受治理 Agent |
| 2 | PRAXO-CORE vs LangChainGo、Eino、ADK Go |
| 3 | 带策略与审计的 MCP 工具 |
| 4 | NOETIVELA、Mnemovela、GNOSIVELA 集成 |
| 6 | 基准方法与结果 |
| 8 | Reference workspace Agent 讲解 |

## 风险

- **GNOSIVELA 没有 v3 semver 标签。** 固定 pseudo-version，并在有标签后更新。
- **MCP SDK 变化。** 将 MCP 适配器放在独立模块并固定版本。
- **提供商碎片化。** 优先覆盖 OpenAI 兼容，再按需求增加原生适配器。
- **过度宣传。** 对比和兼容性说明必须基于事实并注明日期。

## 当前状态

- [x] 带流式输出的 OpenAI 兼容适配器
- [x] MCP 工具网关模块
- [x] Quickstart 与 reference app
- [x] NOETIVELA、Mnemovela、GNOSIVELA SDK recipes
- [x] 中英文文档站与采用指南
- [x] 基准测试与 CI 冒烟运行
- [ ] `v2.1.0` 标签
- [ ] Launch 公告
- [ ] 首个外部案例
