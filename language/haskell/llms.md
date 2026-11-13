# PRAXO-CORE Haskell

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core`
- registry: [Hackage](https://hackage.haskell.org/package/praxo-core-0.4.0)
- source_version: `0.5.0`
- published_version: `0.4.0`
- install_published: `cabal install praxo-core`
- install_source: `cabal install praxo-core`
- source_tag: `haskell/v0.5.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/haskell/

## Capabilities and Status

- OpenAI-compatible model: native (transport seam) (Caller supplies `Transport`; no bundled HTTP client)
- Anthropic model: native (transport seam) (`Praxo.Anthropic`; caller supplies transport)
- Gemini model: native (transport seam) (`Praxo.Gemini`; caller supplies transport)
- MCP client: native (transport seam) (`Praxo.Mcp`; caller supplies `McpTransport`)
- Harmovela sink: native (transport seam) (`Praxo.Harmovela`; caller supplies transport)
- OpenTelemetry sink: native (transport seam) (`Praxo.Otel`; caller supplies `OtelTransport`)
- Subagent delegation: native (synchronous seam) (`Praxo.Delegation.subagentRun`; no asynchronous manager)
- Retriever: native (`Praxo.Retriever.Document` and `Retriever`)

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
