# PRAXO-CORE Erlang

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo_core_erlang`
- registry: [Hex](https://hex.pm/packages/praxo_core_erlang/0.9.0)
- source_version: `0.9.0`
- published_version: `0.9.0`
- install_published: `{praxo_core, "0.9.0", {pkg, praxo_core_erlang}}`
- install_source: `{praxo_core, {path, "language/erlang"}}`
- source_tag: `erlang/v0.9.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/erlang/

## Capabilities and Status

- OpenAI-compatible model: native (`praxo_openai_compatible`; `streaming_model/1` and `generate_stream/3` reassemble SSE content, tool calls, usage, and finish reason)
- Anthropic model: native (`praxo_anthropic`; `streaming_model/1` reassembles Anthropic SSE)
- Gemini model: native (`praxo_gemini`; `streaming_model/1` reassembles Gemini SSE)
- MCP client: native (`praxo_mcp`; stdio, plus `praxo_mcp_http:transport/2` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`praxo_harmovela`)
- OpenTelemetry sink: native (transport seam) (`praxo_otel`; caller supplies transport)
- Subagent delegation: native (synchronous seam) (`praxo_delegation:subagent_run/2`; no asynchronous manager)
- Retriever: native (`praxo_retriever:document`, `func_retriever`, `retrieve/3`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples): runnable language-specific examples.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/erlang/Tutorial): scenario-oriented tutorials.
- [Reference applications](https://github.com/axisvela/praxo-core/tree/main/language/erlang/application): AI-native reference applications.
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
