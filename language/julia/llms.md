# PRAXO-CORE Julia

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `PraxoCore`
- registry: [Julia General (pending)](https://github.com/axisvela/PraxoCore.jl)
- source_version: `0.5.0`
- published_version: `0.2.0`
- install_published: `Pkg.add("PraxoCore")`
- install_source: `Pkg.add(name="PraxoCore", version="0.5.0")`
- source_tag: `julia/v0.5.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/julia/

## Capabilities and Status

- OpenAI-compatible model: native (`OpenAICompatibleModel`)
- Anthropic model: native (`AnthropicModel`; injectable transport)
- Gemini model: native (`GeminiModel`; injectable transport)
- MCP client: native (transport seam) (`mcp_client`; caller supplies transport)
- Harmovela sink: native (`HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`otel_sink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`subagent_run`; no asynchronous manager)
- Retriever: native (`Document`, `FuncRetriever`, `retrieve_documents`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/julia/examples): runnable language-specific examples.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
