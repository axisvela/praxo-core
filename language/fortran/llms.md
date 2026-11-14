# PRAXO-CORE Fortran

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core-fortran`
- registry: Source / CMake
- source_version: `0.9.0`
- published_version: not published
- install_published: not published
- install_source: `Source build (see README)`
- source_tag: `fortran/v0.9.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/fortran/

## Capabilities and Status

- OpenAI-compatible model: native (transport seam) (`openai_compatible`; caller supplies HTTP transport)
- Anthropic model: native (transport seam) (`anthropic_compatible`; caller supplies HTTP transport)
- Gemini model: native (transport seam) (`gemini_compatible`; caller supplies HTTP transport)
- MCP client: native (transport seam) (`mcp_client`; caller supplies transport)
- Harmovela sink: native (transport seam) (`harmovela`; caller supplies HTTP transport)
- OpenTelemetry sink: native (transport seam) (`otel_sink`; caller supplies transport)
- Subagent delegation: native (synchronous seam) (`subagent_run`; no asynchronous manager)
- Retriever: native (`document`, `retriever`, `retrieve_documents`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples): runnable language-specific examples.
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
