# OpenAI-Compatible Model Adapter

`openaicompat` implements `model.Model` for OpenAI-compatible chat completion
endpoints, including Ollama, vLLM, and hosted OpenAI-compatible APIs. It uses
only the Go standard library.

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

Set `APIKey` for endpoints that require a bearer token. Set `HTTP` to supply a
custom client; otherwise the adapter uses a 120-second timeout.

The adapter supports text responses, tool calls, tool choice, usage accounting,
and SSE streaming. Set `agent.Options.OnDelta` to receive streamed text
fragments; the agent uses `GenerateStream` when the model implements
`model.StreamingModel`. Streamed tool-call deltas are aggregated into the final
response. Set `IncludeUsage` to request streamed token usage from endpoints that
support `stream_options.include_usage`.
