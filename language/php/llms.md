# PRAXO-CORE PHP

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `axisvela/praxo-core`
- registry: [Packagist](https://packagist.org/packages/axisvela/praxo-core)
- source_version: `0.7.0`
- published_version: `0.7.0`
- install_published: `composer require axisvela/praxo-core`
- install_source: `composer require axisvela/praxo-core`
- source_tag: `php/v0.7.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/php/

## Capabilities and Status

- OpenAI-compatible model: native (`Praxo\Core\Adapters\OpenAICompatible`)
- Anthropic model: native (`Praxo\Core\Adapters\Anthropic`)
- Gemini model: native (`Praxo\Core\Adapters\Gemini`)
- MCP client: native (`Praxo\Core\Adapters\MCPClient`; stdio, plus `HttpMCPTransport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`Praxo\Core\Adapters\HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`OtelSink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`SubagentManager::run`; no asynchronous manager)
- Retriever: native (`Document`, `Retriever`, `FuncRetriever`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/php/examples): runnable language-specific examples.
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
