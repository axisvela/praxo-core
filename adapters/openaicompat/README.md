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

The adapter supports text responses, tool calls, tool choice, and usage
accounting. It does not implement streaming; wrap it with a streaming adapter if
you need `StreamingModel`.
