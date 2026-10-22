# Quickstart

This quickstart runs a governed agent against an OpenAI-compatible endpoint.
No provider SDK is required.

## Prerequisites

- Go 1.26 or newer
- An OpenAI-compatible endpoint:
  - local Ollama, or
  - a hosted OpenAI-compatible API

## Run with Ollama

```bash
ollama pull llama3.2
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
GOWORK=off go run ./examples/quickstart
```

## Run with a hosted endpoint

```bash
export PRAXO_BASE_URL=https://api.openai.com/v1
export PRAXO_API_KEY=...
export PRAXO_MODEL=gpt-4o-mini
GOWORK=off go run ./examples/quickstart
```

On PowerShell use `$env:PRAXO_BASE_URL = "..."` and the same variable names.
Set `PRAXO_PROMPT` to change the request.

## What the example shows

- a model adapter built on the standard library
- a `get_time` tool exposed through `tool.Registry`
- event delivery through `event.Sink`
- policy authorization through `policy.Hook`
- the governed agent loop

## Next steps

- [OpenAI-compatible adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/openaicompat)
- [MCP tool gateway](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp)
- [Reference workspace agent](https://github.com/axisvela/praxo-core/tree/main/examples/reference)
- [AxisVela ecosystem integration](12-ecosystem.md)
- [Comparison with other Go agent frameworks](comparison.md)
- [Plugin authoring](10-plugin-authoring.md)
