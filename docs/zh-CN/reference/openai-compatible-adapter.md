# OpenAI 兼容模型适配器

这是各 Core 实现原生模型适配器的基线映射。它是适配器指导，不是新的共享 Wire
契约，也不代表 provider 质量。基线不要求 streaming；支持 streaming 的实现必须单独
声明其范围。

## Provider 预设

以下 provider 提供 OpenAI-compatible chat-completions 端点，使用同一适配器和对应 base URL：

| Provider | Base URL |
| --- | --- |
| OpenAI | `https://api.openai.com/v1` |
| DeepSeek | `https://api.deepseek.com/v1` |
| Kimi / Moonshot | `https://api.moonshot.cn/v1` |
| OpenRouter | `https://openrouter.ai/api/v1` |
| Groq | `https://api.groq.com/openai/v1` |
| Together | `https://api.together.xyz/v1` |

Python 与 TypeScript 适配器提供这些预设；Anthropic 与 Gemini 使用原生适配器。

## 端点

`POST {baseURL}/chat/completions`，`content-type: application/json`，可选
`authorization: Bearer {apiKey}`。

## 请求映射

Core model request 映射为：

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

- 省略空的可选字段。
- `content` 为空时，纯文本 content block 列表合并为文本。
- 工具参数在 provider wire 上是 JSON 字符串。
- 只有 tool 消息包含 `tool_call_id`。

## 响应映射

适配器读取首个 choice：

- `message.content` 映射为 assistant content。
- `message.tool_calls[].function.arguments` 从 JSON 字符串解析为 Core 参数对象；
  非法 JSON 是错误，不是空参数。
- `message.tool_calls[].id` 与 `.function.name` 直接映射。
- `usage.prompt_tokens` / `usage.completion_tokens` 映射为 Core input/output token。
- `finish_reason` 映射为 Core response finish reason。

## 失败

- 非 2xx 返回 provider HTTP 错误，包含状态码和有界响应体。
- 缺少 base URL 时在网络调用前拒绝。
- 确定性测试必须注入 transport；生产路径使用该语言的 HTTP 客户端。

## 基线与状态

除 COBOL 外，所有 Core 实现都已有原生适配器。C、C++、Fortran、Haskell 与 OCaml
是 transport-seam 适配器：映射在树内，HTTP transport 由调用方提供。PowerShell 继承
C# Core。COBOL 仍受阻于 HTTP transport 决策与 model callback 的工具/历史扩展。逐语言
说明见[适配器状态](../languages/adapter-status.md)。
