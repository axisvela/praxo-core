# Models And Adapters

Provider, protocol, telemetry, and adapter recipes.

## OpenAI-Compatible Model {#openai-compatible-model}

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
aggregated into the final response. Set `IncludeUsage: true` to request
streamed token usage from compatible endpoints.

See [Quickstart](../../getting-started/quickstart.md) and the
[OpenAI-compatible adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/openaicompat).

## MCP Tools {#mcp-tools}

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

tools, err := mcpadapter.NewTools(ctx, session)
if err != nil {
    return err
}
for _, item := range tools {
    registry.Register(item)
}
```

MCP authentication belongs to the client session. `NewTools` preserves each
server's input schema through `tool.SpecProvider`; the lower-level
`NewGateway`/`tool.NewGatewayTools` path carries only names and descriptions.
If you use `NewGateway` directly, call `Refresh` after the server changes its
tools. Treat every MCP server as untrusted code: run it under the same policy,
sandbox, and credential boundary as other tools, and do not pass ambient
secrets.

The same module exposes resources and prompts:

```go
resources, err := mcpadapter.ListResources(ctx, session)
contents, err := mcpadapter.ReadResource(ctx, session, "embedded:info")
prompts, err := mcpadapter.ListPrompts(ctx, session)
messages, err := mcpadapter.GetPrompt(ctx, session, "greet", map[string]string{
    "name": "Ada",
})
```

See the
[MCP adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp).

## Anthropic Messages {#anthropic-messages}

Use the native adapter for Anthropic models. It supports tool calls, usage, and
SSE streaming.

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

See the
[Anthropic adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/anthropic).

## Gemini generateContent {#gemini-generatecontent}

Use the native adapter for Gemini models. It supports function calls, usage, and
SSE streaming.

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

See the
[Gemini adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/gemini).

## OpenTelemetry Events {#opentelemetry-events}

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

Each event becomes a `praxo.<event.type>` span with session, run, and timestamp
attributes. Adapter v0.2.0 excludes event data by default; use
`AllowedDataKeys` to opt in to individually reviewed fields. Published v0.1.0
exports all event data and requires caller-side filtering before `Emit`. See the
[OpenTelemetry sink](https://github.com/axisvela/praxo-core/tree/main/adapters/otel).
The adapter module also has a runnable, no-collector example:

```bash
cd adapters/otel
GOWORK=off go run ./example
```

## Adapter Conformance Checks {#adapter-conformance-checks}

Use `pkg/conformance` to validate custom model, streaming model, tool, and
retriever adapters without provider credentials.

```go
if err := conformance.CheckModel(ctx, adapter, conformance.ModelCase{
    Request:             model.Request{Messages: []model.Message{{Role: model.RoleUser, Content: "hi"}}},
    WantContentContains: "hello",
}); err != nil {
    return err
}
```

`CheckStreamingModel` checks stream deltas; `CheckTool` checks name, spec, and
invocation; `CheckRetriever` checks results and result limits. See the
[adapter conformance recipe](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/conformance-go).
These are contract checks, not live-provider evidence.

## Retry Safety and Unknown Outcomes {#retry-safety-and-unknown-outcomes}

`pkg/tool.Retry` retries failed invocations according to a policy. The zero
value performs one attempt; configure `Attempts`, `BaseDelay`, `MaxDelay`, and
`ShouldRetry` deliberately. With `Attempts > 1` and no `ShouldRetry`, every
error is retried, including transport or timeout errors whose external effect is
unknown. Do not use that configuration for a non-idempotent tool.

```go
wrapped := tool.Wrap(charge, tool.Retry(tool.RetryPolicy{
    Attempts:    3,
    ShouldRetry: func(err error) bool { return errors.Is(err, errTransient) },
}))
```

A retry is safe only when the failure is known to be harmless or the target
provides idempotency/status resolution. For a non-idempotent effect, query the
authoritative status before retrying:

```go
value, err := charge.Invoke(ctx, args)
if err != nil {
    applied, statusErr := charge.Status(ctx, args)
    if statusErr != nil {
        return nil, statusErr
    }
    if applied {
        return "charged", nil
    }
    return charge.Invoke(ctx, args)
}
```

See the [retry safety recipe](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/retry-go).
The recipe demonstrates the duplicate-effect hazard and the status-aware
alternative; it does not provide a Core effect ledger or exactly-once guarantee.

## Event Sinks and Evidence Failures {#event-sinks-and-evidence-failures}

`pkg/event` supports filtering, fan-out, and publisher adaptation. A failed sink
is not silently treated as durable evidence.

```go
sink := event.MultiSink{
    requiredAuditSink,
    event.FilterSink{
        Sink:      event.PublisherSink{Publisher: publisher},
        Predicate: func(e event.Event) bool { return e.Type == "run.completed" },
    },
}
```

`MultiSink` stops on the first failure, so order required sinks first.
`FilterSink` limits which events reach the wrapped sink; `PublisherSink` adapts
an application publisher. A sink failure before a tool call prevents the
invocation; a `run.failed` sink failure does not mask the original error. See
the [event sink recipe](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/event-sinks-go).
The recipe does not prove durable acknowledgement, storage, or production
telemetry.
