# Provider 与 MCP 演练

本文说明已发布 Core 包如何连接模型和工具 Provider，无需检出仓库。先从
Golden Path 使用的 OpenAI-compatible 路径开始，再指向原生 Anthropic、Gemini
和 MCP Adapter。

## 先使用 OpenAI-Compatible

大多数本地和托管 Provider 提供 OpenAI-compatible 端点。配置一个 base URL、
模型名和可选 API Key：

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
# export PRAXO_API_KEY=...   # 仅托管端点需要
```

各语言示例读取这些变量：

- [Go 真实模型](https://github.com/axisvela/praxo-core/tree/main/examples/live-model/go)
- [Python 真实模型](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/live-model)
- [TypeScript 真实模型](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/live-model)
- [Java 真实模型](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/live-model)

Ollama、vLLM、OpenAI、DeepSeek、Kimi/Moonshot、OpenRouter、Groq 和 Together
都可以通过不同 base URL 使用该 Adapter。Python 和 TypeScript 包还提供命名
Provider 预设。

## 原生 Provider Adapter

当 Provider 协议不同于 OpenAI-compatible Chat Completions 时，使用原生 Adapter：

| Provider | Go | Python | TypeScript | Java |
| --- | --- | --- | --- | --- |
| Anthropic | `adapters/anthropic` | `praxo.adapters.anthropic` | `src/adapters/anthropic.ts` | `adapters.AnthropicModel` |
| Gemini | `adapters/gemini` | `praxo.adapters.gemini` | `src/adapters/gemini.ts` | `adapters.GeminiModel` |

Adapter 仍实现相同的 Core `Model` 契约。工具、Policy、事件、Checkpoint 和
Streaming 仍由应用配置。各语言覆盖范围和限制见
[Adapter 状态](../languages/adapter-status.md)。

## MCP 工具会话

MCP 是工具会话，不是模型 Provider。最小客户端应：

1. 启动或连接 MCP Transport；
2. 初始化会话；
3. 分页列出工具；
4. 将选定工具暴露给 Core Registry；
5. 在每次工具调用前保留 Policy 授权。

Go、Python、TypeScript 和 Java 提供原生 MCP 客户端。其他语言提供调用方
Transport 接缝。增加远程服务器前先阅读
[MCP Adapter 说明](../reference/mcp-client.md)和
[Adapter 状态](../languages/adapter-status.md#mcp)。

## 边界

- Core 映射请求和响应；不提供模型质量、Provider SLA 或托管 MCP 服务。
- MCP 认证属于 Transport 或服务器会话。
- 工具输出仍是不可信输入。
- 本地取消不证明远端工作已停止。
- Provider 凭据和租户策略保留在应用中。

## 相关文档

- [真实模型 Golden Path](../getting-started/live-model-golden-path.md)
- [示例目录](../getting-started/examples.md)
- [OpenAI-compatible Adapter](../reference/openai-compatible-adapter.md)
- [MCP 客户端](../reference/mcp-client.md)
- [Adapter 状态](../languages/adapter-status.md)
