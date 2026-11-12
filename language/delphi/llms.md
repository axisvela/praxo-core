# PRAXO-CORE Delphi / Free Pascal

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `PRAXO-CORE`
- registry: [OPM / GitHub release](https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.2.1)
- source_version: `0.4.0`
- published_version: `0.2.1`
- install_published: `OPM package or release archive`
- install_source: `OPM package or release archive`
- source_tag: `delphi/v0.4.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/delphi/

## Capabilities and Status

- OpenAI-compatible model: native (`TPraxoOpenAIAdapter` with FPC HTTP transport)
- Anthropic model: native (`TPraxoAnthropicAdapter`; FPC HTTP transport)
- Gemini model: native (`TPraxoGeminiAdapter`; FPC HTTP transport)
- MCP client: native (`TPraxoMcpClient`; stdio and `TPraxoHttpMcpTransport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`TPraxoHarmovelaSink`)

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
