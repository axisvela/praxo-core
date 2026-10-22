# Recipes

常用集成的可复制起点。完整可运行示例位于
[`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples)。

## OpenAI 兼容模型

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
文本；工具调用增量会聚合到最终响应中。

参见 [快速开始](quickstart.md) 和
[OpenAI 兼容适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/openaicompat)。

## MCP 工具

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

gateway, err := mcpadapter.NewGateway(ctx, session)
if err != nil {
    return err
}
for _, item := range tool.NewGatewayTools(gateway) {
    registry.Register(item)
}
```

MCP 认证绑定在客户端会话上。服务器工具变化后调用 `gateway.Refresh`。参见
[MCP 网关](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp)。

## Anthropic Messages

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

## OpenTelemetry 事件

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

每个事件会成为 `praxo.<event.type>` span，并带有会话、运行、时间戳和事件数据
属性。参见
[OpenTelemetry Sink](https://github.com/axisvela/praxo-core/tree/main/adapters/otel)。

## NOETIVELA

NOETIVELA 是 AxisVela 的推理基础设施。将其受治理 Chat API 包装为
`model.Model` 适配器。

```go
adapter := noetivelaadapter.Adapter{
    Client: sdk.New("http://localhost:1826"),
    Policy: "legal-confidential-v2",
    ContractFunc: func(model.Request) *sdk.Contract {
        return &sdk.Contract{
            Task:     "status_lookup",
            Modality: []string{"text"},
        }
    },
}
```

该 SDK 暴露文本内容，不暴露工具调用。需要工具调用时，应使用保留 tool-call
字段的自定义 HTTP 适配器。参见
[NOETIVELA SDK 示例](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/noetivela)。

## Mnemovela

Mnemovela 是 Agent Cognition Runtime。其 JSON-RPC 传输可支撑 `memory.Store`。

```go
transport := jsonrpc.New("http://localhost:8080")
store := mnemovelaadapter.Store{
    Client: mnemovela.New(transport),
    Branch: "main",
}

ag, err := agent.New(agent.Options{
    Model:  modelAdapter,
    Memory: store,
    Recall: true,
})
```

参见
[Mnemovela SDK 示例](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/mnemovela)。

## GNOSIVELA

GNOSIVELA grounding 映射到 `retriever.Retriever`。

```go
adapter := gnosivelaadapter.Retriever{
    Client:    gnosivela.New("http://localhost:8080"),
    Principal: "user:demo",
    Purpose:   "status_lookup",
    Budget:    1200,
}

documents, err := adapter.Retrieve(ctx, "current status", 8)
```

GNOSIVELA 尚未为该模块路径发布 `v3` semver 标签；示例模块固定 `master` 的
pseudo-version。参见
[GNOSIVELA SDK 示例](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/gnosivela)。

## Reference Workspace Agent

reference app 组合了 OpenAI 兼容适配器、受限 VFS 工具、策略、记忆、事件和
上下文预算。

```bash
GOWORK=off go run ./examples/reference -workspace ./workspace
```

参见
[reference app](https://github.com/axisvela/praxo-core/tree/main/examples/reference)。
