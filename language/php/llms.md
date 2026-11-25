# PRAXO-CORE PHP

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `axisvela/praxo-core`
- registry: [Packagist](https://packagist.org/packages/axisvela/praxo-core)
- source_version: `0.9.0`
- published_version: `0.8.1`
- install_published: `composer require axisvela/praxo-core`
- install_source: `composer require axisvela/praxo-core`
- source_tag: `php/v0.9.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/php/

## Capabilities and Status

- OpenAI-compatible model: native (`Praxo\Core\Adapters\OpenAICompatible`; implements `StreamingModel` and reassembles SSE content, tool calls, usage, and finish reason)
- Anthropic model: native (`Praxo\Core\Adapters\Anthropic`; implements `StreamingModel` with Anthropic SSE)
- Gemini model: native (`Praxo\Core\Adapters\Gemini`; implements `StreamingModel` with Gemini SSE)
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
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- GitHub Issues: <https://github.com/axisvela/praxo-core/issues>
- Documentation: <https://axisvela.github.io/praxo-core/>
- Architect: <https://axisvela.architect.pub>

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
