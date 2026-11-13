# PRAXO-CORE Rust Registry Introduction

**Status:** published. Source version `0.7.0`, source
tag `rust/v0.7.0`. Published registry version: `0.5.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This crate is its native Rust Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, and plugin manifest parsing. It runs in-process and does not require a hosted service.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [crates.io](https://crates.io/crates/praxo-core/0.5.0) |
| Source version | `0.7.0` |
| Published registry version | `0.5.0` |
| Install (published) | `cargo add praxo-core@0.5.0` |
| Install (source/release prepared) | `cargo add praxo-core@0.7.0` |
| Source tag | `rust/v0.7.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/rust/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `openai_compat` |
| Anthropic model | native (transport seam) | `adapters::anthropic`; caller supplies transport |
| Gemini model | native (transport seam) | `adapters::gemini`; caller supplies transport |
| MCP client | native | `mcp::McpClient`; stdio, plus `McpClient::connect_http` over a caller-supplied `McpHttpTransport` seam for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `harmovela::Sink` |
| OpenTelemetry sink | native (transport seam) | `adapters::otel::Sink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | not implemented |  |
| Retriever | not implemented |  |

## Coding-agent entry

- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
