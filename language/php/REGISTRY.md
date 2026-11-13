# PRAXO-CORE PHP Registry Introduction

**Status:** published. Source version `0.7.1`, source
tag `php/v0.7.0`. Published registry version: `0.4.1`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native PHP Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, and plugin manifest parsing.

## Package

| Field | Value |
| --- | --- |
| Package | `axisvela/praxo-core` |
| Registry | [Packagist](https://packagist.org/packages/axisvela/praxo-core) |
| Source version | `0.7.1` |
| Published registry version | `0.4.1` |
| Install (published) | `composer require axisvela/praxo-core` |
| Install (source/release prepared) | `composer require axisvela/praxo-core` |
| Source tag | `php/v0.7.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/php/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `Praxo\Core\Adapters\OpenAICompatible` |
| Anthropic model | native | `Praxo\Core\Adapters\Anthropic` |
| Gemini model | native | `Praxo\Core\Adapters\Gemini` |
| MCP client | native | `Praxo\Core\Adapters\MCPClient`; stdio, plus `HttpMCPTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `Praxo\Core\Adapters\HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `OtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `SubagentManager::run`; no asynchronous manager |
| Retriever | native | `Document`, `Retriever`, `FuncRetriever` |

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
