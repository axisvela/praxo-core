# PRAXO-CORE D Registry Introduction

**Status:** published. Source version `0.4.0`, source
tag `d/v0.4.0`. Published registry version: `0.1.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native D Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, and plugin manifest parsing.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [DUB](https://code.dlang.org/packages/praxo-core) |
| Source version | `0.4.0` |
| Published registry version | `0.1.0` |
| Install (published) | `dub add praxo-core` |
| Install (source/release prepared) | `dub add praxo-core` |
| Source tag | `d/v0.4.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/d/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native (transport seam) | `OpenAICompatibleModel`; caller may inject transport |
| Anthropic model | native (transport seam) | `AnthropicModel`; caller may inject transport |
| Gemini model | native (transport seam) | `GeminiModel`; caller may inject transport |
| MCP client | native | `praxo.mcp.McpClient`; stdio, plus `HttpMcpTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `OtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `SubagentManager.run` in `praxo.delegation`; no asynchronous manager |
| Retriever | native | `Document`, `Retriever`, `FuncRetriever`, `retrieveDocuments` |

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
