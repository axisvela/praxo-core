# PRAXO-CORE Zig

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core-zig`
- registry: Source
- source_version: `0.5.0`
- published_version: not published
- install_published: not published
- install_source: `Source build (see README)`
- source_tag: `zig/v0.5.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/zig/

## Capabilities and Status

- OpenAI-compatible model: native (`openaicompat.Adapter` with `std.http`)
- Anthropic model: native (`anthropic.Adapter`; injectable transport)
- Gemini model: native (`gemini.Adapter`; injectable transport)
- MCP client: native (`mcp.Client`; stdio and curl-backed `HttpTransport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`harmovela`)
- OpenTelemetry sink: native (transport seam) (`otel.Sink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`delegation.subagentRun`; no asynchronous manager)
- Retriever: native (`retriever.Document`, `retriever.Retriever`, `retriever.retrieveDocuments`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/zig/examples): runnable language-specific examples.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
