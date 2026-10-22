# Recipes

Copy-paste starting points for common integrations. Full runnable examples
live in
[`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples).

## OpenAI-Compatible Model

Works with Ollama, vLLM, and hosted OpenAI-compatible APIs. The adapter uses
only the standard library.

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

The adapter also implements `model.StreamingModel`. Set
`agent.Options.OnDelta` to receive streamed text; tool-call deltas are
aggregated into the final response.

See [Quickstart](quickstart.md) and the
[OpenAI-compatible adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/openaicompat).

## MCP Tools

Use the optional MCP module to expose MCP tools through `tool.Gateway`.

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

MCP authentication belongs to the client session. Call `gateway.Refresh` after
the server changes its tools. See the
[MCP gateway](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp).

## OpenTelemetry Events

Use the optional OpenTelemetry module to turn lifecycle events into spans.

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

Each event becomes a `praxo.<event.type>` span with session, run, timestamp, and
event-data attributes. See the
[OpenTelemetry sink](https://github.com/axisvela/praxo-core/tree/main/adapters/otel).

## NOETIVELA

NOETIVELA is the AxisVela inference fabric. Wrap its governed chat API in a
`model.Model` adapter.

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

The SDK exposes text content, not tool calls. For tool calling, use a custom
HTTP adapter that preserves tool-call fields. See the
[NOETIVELA SDK example](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/noetivela).

## Mnemovela

Mnemovela is the Agent Cognition Runtime. Its JSON-RPC transport backs
`memory.Store`.

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

See the
[Mnemovela SDK example](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/mnemovela).

## GNOSIVELA

GNOSIVELA grounding maps to `retriever.Retriever`.

```go
adapter := gnosivelaadapter.Retriever{
    Client:    gnosivela.New("http://localhost:8080"),
    Principal: "user:demo",
    Purpose:   "status_lookup",
    Budget:    1200,
}

documents, err := adapter.Retrieve(ctx, "current status", 8)
```

GNOSIVELA does not yet publish a `v3` semver tag for this module path; the
example module pins a pseudo-version from `master`. See the
[GNOSIVELA SDK example](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/gnosivela).

## Reference Workspace Agent

The reference app combines the OpenAI-compatible adapter, confined VFS tools,
policy, memory, events, and a context budget.

```bash
GOWORK=off go run ./examples/reference -workspace ./workspace
```

See the
[reference app](https://github.com/axisvela/praxo-core/tree/main/examples/reference).
