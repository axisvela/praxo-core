# PRAXO-CORE V

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core`
- registry: [VPM (pending)](https://github.com/axisvela/praxo-core-v)
- source_version: `0.3.0`
- published_version: `0.1.2`
- install_published: `v install praxo-core`
- install_source: `v install praxo-core`
- source_tag: `v/v0.3.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/v/

## Capabilities and Status

- OpenAI-compatible model: native (`praxo.openaicompat`; verified with V 0.5.2 and `x.json2`)
- Anthropic model: native (transport seam) (`anthropic_compatible`; caller supplies `ProviderTransport`)
- Gemini model: native (transport seam) (`gemini_compatible`; caller supplies `ProviderTransport`)
- MCP client: native (transport seam) (`praxo.mcp`; caller supplies `McpTransport`)
- Harmovela sink: native (`harmovela_sink`; verified with V 0.5.2 and `x.json2`)

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
