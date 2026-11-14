# PRAXO-CORE Elixir

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo_core`
- registry: [Hex](https://hex.pm/packages/praxo_core)
- source_version: `0.8.0`
- published_version: `0.8.0`
- install_published: `{:praxo_core, "~> 0.8.0"}`
- install_source: `{:praxo_core, path: "language/elixir"}`
- source_tag: `elixir/v0.8.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/elixir/

## Capabilities and Status

- OpenAI-compatible model: native (`Praxo.OpenAICompatible`)
- Anthropic model: native (`Praxo.Anthropic`)
- Gemini model: native (`Praxo.Gemini`)
- MCP client: native (`Praxo.Mcp`; stdio, plus `Praxo.McpHttp.transport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`Praxo.HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`Praxo.OtelSink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (`Praxo.SubagentManager`)
- Retriever: native (`Praxo.Document`, `Praxo.FuncRetriever`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples): runnable language-specific examples.
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
