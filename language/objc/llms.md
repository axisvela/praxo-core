# PRAXO-CORE Objective-C

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core-objc`
- registry: Source
- source_version: `0.4.0`
- published_version: not published
- install_published: not published
- install_source: `See README/SETUP.md`
- source_tag: `objc/v0.4.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/objc/

## Capabilities and Status

- OpenAI-compatible model: native (`PXROpenAIGenerate` with injectable transport)
- Anthropic model: native (`PXRAnthropicGenerate` with injectable transport)
- Gemini model: native (`PXRGeminiGenerate` with injectable transport)
- MCP client: native (`PXRMcpClient`; stdio and `PXRHttpMcpTransport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`PraxoHarmovela`)
- OpenTelemetry sink: native (transport seam) (`PXROtelSink`; caller supplies `PXROtelTransport`)
- Subagent delegation: native (synchronous seam) (`PXRSubagentRun`; no asynchronous manager)
- Retriever: native (`PXDocument`, `PXRetriever`, `PXRetrieveDocuments`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/objc/examples): runnable language-specific examples.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
