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
| MCP | `github.com/axisvela/praxo-core/adapters/mcp` | `tool.Gateway`, resources, prompts | `adapters/mcp/v0.3.0` |
| OpenTelemetry | `github.com/axisvela/praxo-core/adapters/otel` | `event.Sink` | `adapters/otel/v0.2.0` |
| Harmovela | `github.com/axisvela/praxo-core/adapters/harmovela` | `event.Sink` | `adapters/harmovela/v0.1.0` |
| A2A | `github.com/axisvela/praxo-core/adapters/a2a` | `a2asrv.AgentExecutor` | `adapters/a2a/v0.1.0` |
| Multi-agent | `github.com/axisvela/praxo-core/adapters/multiagent` | supervisor and sequential delegation | `adapters/multiagent/v0.2.0` |

The MCP module exposes tools through `tool.Gateway` and provides module-level
helpers for resources and prompts. Use `NewTools` for model-facing registration:
it preserves each server's input schema, unlike the generic
`tool.NewGatewayTools` path. The OpenTelemetry module maps lifecycle events to
spans and excludes event data by default.

The A2A adapter has in-process JSON-RPC and gRPC round-trip tests plus a
[Google ADK Go external-consumer example](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-adk-order-cancellation)
for agent-card discovery, JSON-RPC message exchange, optional bearer
authentication, a two-process loopback run, concurrent consumers, loopback TLS
termination, and cross-origin card rejection. The `enterprise-autonomy`
repository also has direct and LIMENORA-fronted Agent IAM contract examples
combining NOMIVELA, EIDOVELA, AEGIVELA, Google ADK, and PRAXO-CORE. They are not
production, deployed-peer, external gRPC, deployed TLS, or deployed-load
evidence.

The [local IAM run record](https://github.com/axisvela/enterprise-autonomy/blob/f7c3177/examples/a2a-agent-iam-local/RUN-RECORD.md#v2-verification-update)
also records a direct Google ADK -> PRAXO-CORE A2A call using real local IAM
services with `system_api` authorization, and a separate patched AEGIVELA
`serviceAgentApi` v2 decision returning `allow` (policy `v1`). The v2 backend
fixes are recorded in AEGIVELA commit `3ceb44c`. Targeted backend regression
tests and `go vet ./...` passed, but the full backend test suite remains blocked
by a separate generated identity protobuf descriptor panic. These results do
not establish end-to-end v2 A2A, instance-lease enforcement, or a real LIMENORA
reverse-ingress route. No framework API or adapter version changes are involved.

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
