# PRAXO-CORE Rust Registry Introduction

**Status:** published. Source version `0.10.0`, source
tag `rust/v0.10.0`. Published registry version: `0.10.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This crate is its native Rust Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, and plugin manifest parsing. It runs in-process and does not require a hosted service.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [crates.io](https://crates.io/crates/praxo-core/0.10.0) |
| Source version | `0.10.0` |
| Published registry version | `0.10.0` |
| Install (published) | `cargo add praxo-core@0.10.0` |
| Install (source/release prepared) | `cargo add --path language/rust` |
| Source tag | `rust/v0.10.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/rust/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `openai_compat::OpenAICompatible` behind optional `http-ureq`; `parse_stream` always available |
| Anthropic model | native (transport seam) | `adapters::anthropic`; caller supplies transport; `StreamingModel` via `send_stream` |
| Gemini model | native (transport seam) | `adapters::gemini`; caller supplies transport; `StreamingModel` via `send_stream` |
| MCP client | native | `mcp::McpClient`; stdio, plus `McpClient::connect_http` over a caller-supplied `McpHttpTransport` seam for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `harmovela::Sink` |
| OpenTelemetry sink | native (transport seam) | `adapters::otel::Sink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native | `delegation::SubagentManager` |
| Retriever | native | `retriever::Document` and `Retriever` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples): runnable language-specific examples.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial): scenario-oriented tutorials.
- [Reference applications](https://github.com/axisvela/praxo-core/tree/main/language/rust/application): AI-native reference applications.
- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

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

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
