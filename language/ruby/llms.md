# PRAXO-CORE Ruby

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core`
- registry: [RubyGems](https://rubygems.org/gems/praxo-core/versions/0.7.0)
- source_version: `0.7.0`
- published_version: `0.7.0`
- install_published: `gem install praxo-core`
- install_source: `gem install praxo-core`
- source_tag: `ruby/v0.7.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/ruby/

## Capabilities and Status

- OpenAI-compatible model: native (`Praxo::Adapters::OpenAICompatible`)
- Anthropic model: native (`Praxo::Adapters::Anthropic`; injectable transport)
- Gemini model: native (`Praxo::Adapters::Gemini`; injectable transport)
- MCP client: native (`Praxo::Adapters::MCPClient`; stdio, plus `HttpMCPTransport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`Praxo::Adapters::HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`OtelSink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (`Delegation::SubagentManager`)
- Retriever: native (`Document`, `FuncRetriever`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
