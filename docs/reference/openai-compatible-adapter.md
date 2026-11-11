# OpenAI-Compatible Model Adapter

This is the baseline mapping for a native model adapter in a Core
implementation. It is adapter guidance, not a new shared wire contract or a
provider-quality claim. Streaming remains optional for the baseline; an
implementation that supports streaming must document it separately.

## Provider Presets

These providers expose an OpenAI-compatible chat-completions endpoint and use
this adapter with the listed base URL:

| Provider | Base URL |
| --- | --- |
| OpenAI | `https://api.openai.com/v1` |
| DeepSeek | `https://api.deepseek.com/v1` |
| Kimi / Moonshot | `https://api.moonshot.cn/v1` |
| OpenRouter | `https://openrouter.ai/api/v1` |
| Groq | `https://api.groq.com/openai/v1` |
| Together | `https://api.together.xyz/v1` |

The Python and TypeScript adapters expose these values as provider presets.
Anthropic and Gemini use native adapters instead.

## Endpoint

`POST {baseURL}/chat/completions` with `content-type: application/json` and an
optional `authorization: Bearer {apiKey}` header.

## Request Mapping

The adapter maps the Core model request to:

```json
{
  "model": "provider-model-id",
  "messages": [
    {"role": "system", "content": "..."},
    {"role": "user", "content": "..."},
    {
      "role": "assistant",
      "content": "",
      "tool_calls": [
        {
          "id": "call-1",
          "type": "function",
          "function": {"name": "echo", "arguments": "{\"text\":\"hi\"}"}
        }
      ]
    },
    {"role": "tool", "content": "{\"ok\":true}", "tool_call_id": "call-1"}
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "echo",
        "description": "Echo arguments",
        "parameters": {"type": "object"}
      }
    }
  ],
  "tool_choice": "auto",
  "response_format": {"type": "json_object"},
  "temperature": 0
}
```

- Omit empty optional fields.
- A text-only content block list becomes its joined text when `content` is empty.
- Tool arguments are JSON-encoded strings on the provider wire.
- `tool_call_id` is present only for tool messages.

## Response Mapping

The adapter reads the first choice:

- `message.content` becomes the assistant content.
- `message.tool_calls[].function.arguments` is parsed from a JSON string into a
  Core argument object. Invalid JSON is an error, not an empty argument map.
- `message.tool_calls[].id` and `.function.name` map directly.
- `usage.prompt_tokens` and `usage.completion_tokens` map to Core input/output
  token usage.
- `finish_reason` maps to the Core response finish reason.

## Failures

- Non-2xx responses produce a provider HTTP error containing the status and a
  bounded response body.
- A missing base URL is rejected before a network call.
- Transport injection is required for deterministic tests; the production path
  uses the language's HTTP client.

## Baseline Status

Native adapters now cover every Core implementation except COBOL. C, C++,
Fortran, Haskell, and OCaml are transport-seam adapters: the mapping is in-tree
and the caller supplies the HTTP transport. PowerShell inherits the C# Core.
COBOL is blocked on an HTTP transport decision and a model-callback extension for
tool specs and history. See the [adapter status](../languages/adapter-status.md)
page for per-language notes.
