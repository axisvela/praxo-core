# PRAXO-CORE Lua

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core`
- registry: [LuaRocks](https://luarocks.org/modules/hanhhuiwen/praxo-core)
- source_version: `0.6.0-1`
- published_version: `0.6.0-1`
- install_published: `luarocks install praxo-core 0.6.0-1`
- install_source: `luarocks install praxo-core 0.6.0-1`
- source_tag: `lua/v0.6.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/lua/

## Capabilities and Status

- OpenAI-compatible model: native (`praxo.openai_compatible`)
- Anthropic model: native (`praxo.adapters.anthropic`)
- Gemini model: native (`praxo.adapters.gemini`)
- MCP client: native (transport seam) (`praxo.adapters.mcp`; caller supplies transport)
- Harmovela sink: native (`praxo.harmovela_sink`)
- OpenTelemetry sink: native (transport seam) (`adapters.otel_sink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`subagent_run`; no asynchronous manager)
- Retriever: native (`document`, `func_retriever`, `retriever_retrieve`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](examples/): runnable language-specific examples.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
