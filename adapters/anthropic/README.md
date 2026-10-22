# Anthropic Model Adapter

`adapters/anthropic` implements `model.Model` and `model.StreamingModel` for the
Anthropic Messages API. It uses only the Go standard library.

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

## Mapping

- System messages become the top-level `system` field.
- Assistant tool calls become `tool_use` content blocks.
- Consecutive tool results are grouped into one `user` message with
  `tool_result` blocks.
- Tool choice maps `auto`, `required`, and `none` to Anthropic equivalents.
- Usage maps `input_tokens`, `output_tokens`, and `cache_read_input_tokens`.

## Streaming

`GenerateStream` parses Anthropic SSE events, forwards `text_delta` content to
`agent.Options.OnDelta`, and aggregates `input_json_delta` fragments into final
tool-call arguments.

## Limitations

- Text and tool content are supported; image content blocks are ignored.
- The adapter requires an API key and a model name.
- `max_tokens` defaults to 1024 when unset.
