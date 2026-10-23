# 适配器索引

PRAXO-CORE 保持核心 `pkg/...` API 冻结，适配器放在可选包和独立模块中。本页
列出当前支持的适配器及其 tag。

## 模型适配器

| 适配器 | 导入路径 | 接缝 | 状态 |
| --- | --- | --- | --- |
| OpenAI 兼容 | `github.com/axisvela/praxo-core/v2/adapters/openaicompat` | `model.Model`、`model.StreamingModel` | 位于核心模块 |
| Anthropic | `github.com/axisvela/praxo-core/adapters/anthropic` | `model.Model`、`model.StreamingModel` | `adapters/anthropic/v0.1.0` |
| Gemini | `github.com/axisvela/praxo-core/adapters/gemini` | `model.Model`、`model.StreamingModel` | `adapters/gemini/v0.1.0` |

OpenAI 兼容适配器仅使用标准库，适用于 Ollama、vLLM 和托管 OpenAI 兼容端点。
支持的端点可设置 `IncludeUsage` 获取流式 token 用量。Anthropic 与 Gemini 是
对应 API 的原生适配器。

## 工具与协议适配器

| 适配器 | 导入路径 | 接缝 | 状态 |
| --- | --- | --- | --- |
| MCP | `github.com/axisvela/praxo-core/adapters/mcp` | `tool.Gateway`、resources、prompts | `adapters/mcp/v0.3.0` |
| OpenTelemetry | `github.com/axisvela/praxo-core/adapters/otel` | `event.Sink` | `adapters/otel/v0.2.0` |
| Harmovela | `github.com/axisvela/praxo-core/adapters/harmovela` | `event.Sink` | `adapters/harmovela/v0.1.0` |
| A2A | `github.com/axisvela/praxo-core/adapters/a2a` | `a2asrv.AgentExecutor` | `adapters/a2a/v0.1.0` |
| Multi-agent | `github.com/axisvela/praxo-core/adapters/multiagent` | supervisor 与顺序委派 | `adapters/multiagent/v0.2.0` |

MCP 模块通过 `tool.Gateway` 暴露工具，并提供 resources 和 prompts 的模块级
辅助函数。OpenTelemetry 模块将生命周期事件映射为 span。

## AxisVela SDK Recipes

这些 recipes 位于
[`examples/ecosystem-sdk`](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk)，
是示例而不是已发布的适配器模块。

| 组件 | 适配器 | 接缝 |
| --- | --- | --- |
| NOETIVELA | `noetivela.Adapter` | `model.Model` |
| Mnemovela | `mnemovela.Store` | `memory.Store` |
| GNOSIVELA | `gnosivela.Retriever` | `retriever.Retriever` |
| AEGIVELA | `aegivela.Hook` | `policy.Hook` |
| LIMENORA | `limenora.Gateway` | `tool.Gateway` |
| RHEOVELA | `rheovela.Runner` | Agent 会话到工作流实例 |

Harmovela 是已发布的适配器模块，而不是 recipe：它直接使用 HTTP events 协议，
不需要较重的 Harmovela Go 模块。

## 新增适配器

1. 实现对应的核心接口。
2. 不要把产品 SDK 放入核心模块；需要时使用独立模块。
3. 添加测试，包括 `var _ model.Model = Adapter{}` 之类的编译期断言。
4. 记录映射关系和限制。
5. 可选模块使用 `adapters/<name>/vX.Y.Z` 标签。

可复制示例参见 [Recipes](recipes.md)，完整集成映射参见
[AxisVela 生态](12-ecosystem.md)。
