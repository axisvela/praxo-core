# PRAXO-CORE PHP Registry Introduction

**Status:** published. Source version `0.10.0`, source
tag `php/v0.10.0`. Published registry version: `0.8.1`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native PHP Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, and plugin manifest parsing.

## Package

| Field | Value |
| --- | --- |
| Package | `axisvela/praxo-core` |
| Registry | [Packagist](https://packagist.org/packages/axisvela/praxo-core) |
| Source version | `0.10.0` |
| Published registry version | `0.8.1` |
| Install (published) | `composer require axisvela/praxo-core` |
| Install (source/release prepared) | `composer require axisvela/praxo-core` |
| Source tag | `php/v0.10.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/php/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `Praxo\Core\Adapters\OpenAICompatible`; implements `StreamingModel` and reassembles SSE content, tool calls, usage, and finish reason |
| Anthropic model | native | `Praxo\Core\Adapters\Anthropic`; implements `StreamingModel` with Anthropic SSE |
| Gemini model | native | `Praxo\Core\Adapters\Gemini`; implements `StreamingModel` with Gemini SSE |
| MCP client | native | `Praxo\Core\Adapters\MCPClient`; stdio, plus `HttpMCPTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `Praxo\Core\Adapters\HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `OtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `SubagentManager::run`; no asynchronous manager |
| Retriever | native | `Document`, `Retriever`, `FuncRetriever` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/php/examples): runnable language-specific examples.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial): scenario-oriented tutorials.
- [Reference applications](https://github.com/axisvela/praxo-core/tree/main/language/php/application): AI-native reference applications.
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
