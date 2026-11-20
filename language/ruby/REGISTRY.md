# PRAXO-CORE Ruby Registry Introduction

**Status:** published; split source repository. Source version `0.9.0`, source
tag `ruby/v0.9.0`. Published registry version: `0.9.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This gem is its native Ruby Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, and plugin manifest parsing.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [RubyGems](https://rubygems.org/gems/praxo-core/versions/0.9.0) |
| Source version | `0.9.0` |
| Published registry version | `0.9.0` |
| Install (published) | `gem install praxo-core` |
| Install (source/release prepared) | `gem install praxo-core` |
| Source tag | `ruby/v0.9.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/ruby/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `Praxo::Adapters::OpenAICompatible`; `generate_stream` reassembles SSE content, tool calls, usage, and finish reason |
| Anthropic model | native | `Praxo::Adapters::Anthropic`; injectable transport; `generate_stream` reassembles Anthropic SSE |
| Gemini model | native | `Praxo::Adapters::Gemini`; injectable transport; `generate_stream` reassembles Gemini SSE |
| MCP client | native | `Praxo::Adapters::MCPClient`; stdio, plus `HttpMCPTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `Praxo::Adapters::HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `OtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native | `Delegation::SubagentManager` |
| Retriever | native | `Document`, `FuncRetriever` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples): runnable language-specific examples.
- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
