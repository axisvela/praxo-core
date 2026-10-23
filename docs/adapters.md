# Adapter Index

PRAXO-CORE keeps the core `pkg/...` API frozen while adapters live in optional
packages and modules. This page lists the supported adapters and their current
tags.

## Model Adapters

| Adapter | Import | Seam | Status |
| --- | --- | --- | --- |
| OpenAI-compatible | `github.com/axisvela/praxo-core/v2/adapters/openaicompat` | `model.Model`, `model.StreamingModel` | in the core module |
| Anthropic | `github.com/axisvela/praxo-core/adapters/anthropic` | `model.Model`, `model.StreamingModel` | `adapters/anthropic/v0.1.0` |
| Gemini | `github.com/axisvela/praxo-core/adapters/gemini` | `model.Model`, `model.StreamingModel` | `adapters/gemini/v0.1.0` |

The OpenAI-compatible adapter uses only the standard library and works with
Ollama, vLLM, and hosted OpenAI-compatible endpoints. Set `IncludeUsage` for
streamed token usage on endpoints that support it. Anthropic and Gemini are
native adapters for their respective APIs.

## Tool and Protocol Adapters

| Adapter | Import | Seam | Status |
| --- | --- | --- | --- |
| MCP | `github.com/axisvela/praxo-core/adapters/mcp` | `tool.Gateway`, resources, prompts | `adapters/mcp/v0.2.0` |
| OpenTelemetry | `github.com/axisvela/praxo-core/adapters/otel` | `event.Sink` | `adapters/otel/v0.2.0` |
| Harmovela | `github.com/axisvela/praxo-core/adapters/harmovela` | `event.Sink` | `adapters/harmovela/v0.1.0` |
| A2A | `github.com/axisvela/praxo-core/adapters/a2a` | `a2asrv.AgentExecutor` | `adapters/a2a/v0.1.0` |
| Multi-agent | `github.com/axisvela/praxo-core/adapters/multiagent` | supervisor and sequential delegation | `adapters/multiagent/v0.1.0` |

The MCP module exposes tools through `tool.Gateway` and provides module-level
helpers for resources and prompts. The OpenTelemetry module maps lifecycle
events to spans.

## AxisVela SDK Recipes

These recipes live in
[`examples/ecosystem-sdk`](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk)
and are examples rather than published adapter modules.

| Component | Adapter | Seam |
| --- | --- | --- |
| NOETIVELA | `noetivela.Adapter` | `model.Model` |
| Mnemovela | `mnemovela.Store` | `memory.Store` |
| GNOSIVELA | `gnosivela.Retriever` | `retriever.Retriever` |
| AEGIVELA | `aegivela.Hook` | `policy.Hook` |
| LIMENORA | `limenora.Gateway` | `tool.Gateway` |
| RHEOVELA | `rheovela.Runner` | agent session to workflow instance |

Harmovela is a published adapter module rather than a recipe because it uses the
HTTP events protocol directly and does not need the heavier Harmovela Go module.

## Adding an Adapter

1. Implement the relevant core interface.
2. Keep product SDKs out of the core module; use a separate module when needed.
3. Add tests, including a conformance assertion such as `var _ model.Model = Adapter{}`.
4. Document the mapping and limitations.
5. Tag optional modules as `adapters/<name>/vX.Y.Z`.

See [Recipes](recipes.md) for copy-paste examples and
[AxisVela ecosystem](12-ecosystem.md) for the broader integration map.
