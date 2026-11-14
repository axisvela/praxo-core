# PRAXO-CORE Java

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `com.axisvela:praxo-core`
- registry: [Maven Central](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.9.0/)
- source_version: `0.9.0`
- published_version: `0.9.0`
- install_published: `Maven: com.axisvela:praxo-core:0.9.0`
- install_source: `Maven source build (see README)`
- source_tag: `java/v0.9.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/java/

## Capabilities and Status

- OpenAI-compatible model: native (`adapters.OpenAICompatibleModel`)
- Anthropic model: native (`adapters.AnthropicModel`)
- Gemini model: native (`adapters.GeminiModel`)
- MCP client: native (`adapters.McpClient`; stdio, plus `McpStreamableHttpTransport` for Streamable HTTP 2025-03-26 (local runtime verification pending))
- Harmovela sink: native (`adapters.HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`adapters.OtelSink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (`agent.delegation.SubagentManager`)
- Retriever: native (`retriever.Document` and `Retriever`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/java/examples): runnable language-specific examples.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
