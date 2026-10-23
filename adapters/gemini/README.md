# Gemini Model Adapter

`adapters/gemini` implements `model.Model` and `model.StreamingModel` for the
Gemini `generateContent` API. It uses only the Go standard library.

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

## Mapping

- System messages become `system_instruction`.
- User and assistant messages map to `user` and `model` roles.
- Assistant tool calls become `functionCall` parts.
- Tool results become `functionResponse` parts, grouped into a user message.
- `ToolChoice` maps `auto`, `required`, and `none` to `AUTO`, `ANY`, and `NONE`.
- Usage maps prompt, candidate, and cached-content token counts.

## Streaming

`GenerateStream` parses Gemini SSE chunks, forwards text deltas to
`agent.Options.OnDelta`, and aggregates function calls into the final response.

## Limitations

- Text and tool content are supported; image content is ignored.
- The adapter requires an API key and a model name.
- Function calls receive deterministic local IDs (`call-1`, `call-2`, ...).
