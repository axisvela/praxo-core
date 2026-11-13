# PRAXO-CORE Erlang

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo_core_erlang`
- registry: [Hex](https://hex.pm/packages/praxo_core_erlang/0.5.0)
- source_version: `0.6.0`
- published_version: `0.5.0`
- install_published: `{deps, [{praxo_core_erlang, "0.5.0"}]}.`
- install_source: `{deps, [{praxo_core_erlang, "0.6.0"}]}.`
- source_tag: `erlang/v0.6.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/erlang/

## Capabilities and Status

- OpenAI-compatible model: native (`praxo_openai_compatible`)
- Anthropic model: native (`praxo_anthropic`)
- Gemini model: native (`praxo_gemini`)
- MCP client: native (`praxo_mcp`; stdio, plus `praxo_mcp_http:transport/2` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`praxo_harmovela`)
- OpenTelemetry sink: not implemented
- Subagent delegation: not implemented
- Retriever: not implemented

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
