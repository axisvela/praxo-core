# 模型与适配器

Provider、协议、遥测与适配器配方。

## OpenAI 兼容模型 {#openai-compatible-model}

适用于 Ollama、vLLM 和托管的 OpenAI 兼容 API。适配器只使用标准库。

```go
adapter := openaicompat.Adapter{
    BaseURL: "http://localhost:11434/v1",
    Model:   "llama3.2",
}

ag, err := agent.New(agent.Options{
    Model:    adapter,
    MaxSteps: 4,
})
```

该适配器也实现 `model.StreamingModel`。设置 `agent.Options.OnDelta` 可接收流式
文本；工具调用增量会聚合到最终响应中。支持的端点可设置 `IncludeUsage: true`
获取流式 token 用量。

参见 [快速开始](../../getting-started/quickstart.md) 和
[OpenAI 兼容适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/openaicompat)。

## MCP 工具 {#mcp-tools}

使用可选的 MCP 模块，通过 `tool.Gateway` 暴露 MCP 工具。

```go
client := mcpsdk.NewClient(&mcpsdk.Implementation{Name: "agent", Version: "v0.1.0"}, nil)
session, err := client.Connect(ctx, &mcpsdk.CommandTransport{
    Command: exec.Command("my-mcp-server"),
}, nil)
if err != nil {
    return err
}
defer session.Close()

tools, err := mcpadapter.NewTools(ctx, session)
if err != nil {
    return err
}
for _, item := range tools {
    registry.Register(item)
}
```

MCP 认证绑定在客户端会话上。`NewTools` 通过 `tool.SpecProvider` 保留每个
server 的输入 schema；底层 `NewGateway`/`tool.NewGatewayTools` 路径只携带名称
和描述。若直接使用 `NewGateway`，服务器工具变化后调用 `Refresh`。应将每个
MCP server 视为不可信代码：与其他工具使用相同的策略、sandbox 和凭据边界，
不要传递环境中的隐式密钥。

同一模块也暴露 resources 和 prompts：

```go
resources, err := mcpadapter.ListResources(ctx, session)
contents, err := mcpadapter.ReadResource(ctx, session, "embedded:info")
prompts, err := mcpadapter.ListPrompts(ctx, session)
messages, err := mcpadapter.GetPrompt(ctx, session, "greet", map[string]string{
    "name": "Ada",
})
```

参见
[MCP 适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp)。

## Anthropic Messages {#anthropic-messages}

使用原生适配器连接 Anthropic 模型，支持工具调用、usage 和 SSE 流式输出。

```go
adapter := anthropic.Adapter{
    APIKey:    os.Getenv("ANTHROPIC_API_KEY"),
    Model:     "claude-sonnet-4-5",
    MaxTokens: 1024,
}

ag, err := agent.New(agent.Options{
    Model:    adapter,
    MaxSteps: 4,
})
```

参见
[Anthropic 适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/anthropic)。

## Gemini generateContent {#gemini-generatecontent}

使用原生适配器连接 Gemini 模型，支持 function call、usage 和 SSE 流式输出。

```go
adapter := gemini.Adapter{
    APIKey:    os.Getenv("GEMINI_API_KEY"),
    Model:     "gemini-2.5-pro",
    MaxTokens: 1024,
}

ag, err := agent.New(agent.Options{
    Model:    adapter,
    MaxSteps: 4,
})
```

参见
[Gemini 适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/gemini)。

## OpenTelemetry 事件 {#opentelemetry-events}

使用可选的 OpenTelemetry 模块将生命周期事件转换为 span。

```go
provider := sdktrace.NewTracerProvider(
    sdktrace.WithBatcher(exporter),
)
defer provider.Shutdown(ctx)

ag, err := agent.New(agent.Options{
    Model:  modelAdapter,
    Events: otelsink.New(provider),
})
```

每个事件会成为 `praxo.<event.type>` span，并带有会话、运行和时间戳属性。
适配器 v0.2.0 默认排除事件数据，可通过 `AllowedDataKeys` 选择经过审查的字段。
已发布的 v0.1.0 会导出全部事件数据，需在调用 `Emit` 前自行过滤。参见
[OpenTelemetry Sink](https://github.com/axisvela/praxo-core/tree/main/adapters/otel)。
