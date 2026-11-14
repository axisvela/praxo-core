# PRAXO-CORE D

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core`
- registry: [DUB](https://code.dlang.org/packages/praxo-core)
- source_version: `0.4.0`
- published_version: `0.1.0`
- install_published: `dub add praxo-core`
- install_source: `dub add praxo-core`
- source_tag: `d/v0.4.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/d/

## Capabilities and Status

- OpenAI-compatible model: native (transport seam) (`OpenAICompatibleModel`; caller may inject transport)
- Anthropic model: native (transport seam) (`AnthropicModel`; caller may inject transport)
- Gemini model: native (transport seam) (`GeminiModel`; caller may inject transport)
- MCP client: native (`praxo.mcp.McpClient`; stdio, plus `HttpMcpTransport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`OtelSink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`SubagentManager.run` in `praxo.delegation`; no asynchronous manager)
- Retriever: native (`Document`, `Retriever`, `FuncRetriever`, `retrieveDocuments`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/d/examples): runnable language-specific examples.
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
