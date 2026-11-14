# PRAXO-CORE Python

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core`
- registry: [PyPI](https://pypi.org/project/praxo-core/0.6.0/)
- source_version: `0.7.0`
- published_version: `0.6.0`
- install_published: `pip install praxo-core==0.6.0`
- install_source: `pip install ./language/python`
- source_tag: `python/v0.6.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/python/

## Capabilities and Status

- OpenAI-compatible model: native (`praxo.adapters.openaicompat`)
- Anthropic model: native (`praxo.adapters.anthropic.AnthropicModel`)
- Gemini model: native (`praxo.adapters.gemini.GeminiModel`)
- MCP client: native (`praxo.adapters.mcp.MCPClient`; stdio, plus `mcp_http.StreamableHTTPTransport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`praxo.adapters.harmovela.HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`praxo.adapters.otel.OtelSink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (`praxo.delegation.SubagentManager`)
- Retriever: native (`praxo.retriever.Document` and `Retriever`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/python/examples): runnable language-specific examples.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
