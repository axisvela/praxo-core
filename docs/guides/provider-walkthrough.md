# Provider and MCP Walkthrough

This walkthrough shows how the published Core packages connect to model and tool
providers without a repository checkout. It starts with the OpenAI-compatible
path used by the Golden Path, then points to native Anthropic, Gemini, and MCP
adapters.

## OpenAI-Compatible First

Most local and hosted providers expose an OpenAI-compatible endpoint. Configure
one base URL, model name, and optional API key:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
# export PRAXO_API_KEY=...   # hosted endpoints only
```

The language examples read these variables:

- [Go live model](https://github.com/axisvela/praxo-core/tree/main/examples/live-model/go)
- [Python live model](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/live-model)
- [TypeScript live model](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/live-model)
- [Java live model](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/live-model)

Ollama, vLLM, OpenAI, DeepSeek, Kimi/Moonshot, OpenRouter, Groq, and Together can
use this adapter with different base URLs. The Python and TypeScript packages
also expose named provider presets.

## Native Provider Adapters

Use a native adapter when the provider protocol differs from OpenAI-compatible
chat completions:

| Provider | Go | Python | TypeScript | Java |
| --- | --- | --- | --- | --- |
| Anthropic | `adapters/anthropic` | `praxo.adapters.anthropic` | `src/adapters/anthropic.ts` | `adapters.AnthropicModel` |
| Gemini | `adapters/gemini` | `praxo.adapters.gemini` | `src/adapters/gemini.ts` | `adapters.GeminiModel` |

The adapter still implements the same Core `Model` contract. Tools, policy,
events, checkpoints, and streaming remain application-configured. See
[adapter status](../languages/adapter-status.md) for per-language coverage and
limits.

## MCP Tool Sessions

MCP is a tool session, not a model provider. A minimal client should:

1. start or connect to the MCP transport;
2. initialize the session;
3. list tools with pagination;
4. expose selected tools through the Core registry;
5. keep policy authorization in front of every tool call.

Go, Python, TypeScript, and Java provide native MCP clients. Other languages
provide caller-supplied transport seams. Read the
[MCP adapter notes](../reference/mcp-client.md) and
[adapter status](../languages/adapter-status.md#mcp) before adding a remote
server.

## Boundaries

- Core maps requests and responses; it does not provide model quality, provider
  SLAs, or hosted MCP services.
- MCP authentication belongs to the transport or server session.
- Tool output remains untrusted input.
- Local cancellation does not prove remote work stopped.
- Provider credentials and tenant policy stay in the application.

## Related

- [Live Model Golden Path](../getting-started/live-model-golden-path.md)
- [Examples](../getting-started/examples.md)
- [OpenAI-compatible adapter](../reference/openai-compatible-adapter.md)
- [MCP client](../reference/mcp-client.md)
- [Adapter status](../languages/adapter-status.md)
