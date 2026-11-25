# PRAXO-CORE Haskell Registry Introduction

**Status:** published. Source version `0.9.0`, source
tag `haskell/v0.9.0`. Published registry version: `0.8.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed AI agent framework. This package is its native Haskell Core. It implements all eleven declared vector groups and does not call Go or another Core. It includes a native callback-based agent loop with tools, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, plugin manifest parsing, and runtime helpers.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [Hackage](https://hackage.haskell.org/package/praxo-core-0.8.0) |
| Source version | `0.9.0` |
| Published registry version | `0.8.0` |
| Install (published) | `cabal install praxo-core` |
| Install (source/release prepared) | `cabal install praxo-core` |
| Source tag | `haskell/v0.9.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/haskell/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native (transport seam) | Caller supplies `Transport`; no bundled HTTP client; SSE streaming reassembly |
| Anthropic model | native (transport seam) | `Praxo.Anthropic`; caller supplies transport; `generateAnthropicStream` reassembles Anthropic SSE |
| Gemini model | native (transport seam) | `Praxo.Gemini`; caller supplies transport; `generateGeminiStream` reassembles Gemini SSE |
| MCP client | native (transport seam) | `Praxo.Mcp`; caller supplies `McpTransport` |
| Harmovela sink | native (transport seam) | `Praxo.Harmovela`; caller supplies transport |
| OpenTelemetry sink | native (transport seam) | `Praxo.Otel`; caller supplies `OtelTransport` |
| Subagent delegation | native (synchronous seam) | `Praxo.Delegation.subagentRun`; no asynchronous manager |
| Retriever | native | `Praxo.Retriever.Document` and `Retriever` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/haskell/examples): runnable language-specific examples.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial): scenario-oriented tutorials.
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
