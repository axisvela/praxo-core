# PRAXO-CORE R Registry Introduction

**Status:** published on r-universe; CRAN not published. Source version `0.11.0`, source
tag `r/v0.11.0`. Published registry version: `0.11.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native R Core: an in-process agent loop with tools, policy, events, memory, checkpoints, middleware, and JSON Schema validation, implemented in base R.

## Package

| Field | Value |
| --- | --- |
| Package | `praxocore` |
| Registry | [r-universe](https://axisvela.r-universe.dev/praxocore) |
| Source version | `0.11.0` |
| Published registry version | `0.11.0` |
| Install (published) | `install.packages("praxocore", repos = "https://axisvela.r-universe.dev")` |
| Install (source/release prepared) | `install.packages("praxocore", repos = "https://axisvela.r-universe.dev")` |
| Source tag | `r/v0.11.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/r/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `openai_compatible` adapter; `openai_compatible_streaming_model` reassembles SSE content, tool calls, usage, and finish reason |
| Anthropic model | native (transport seam) | `anthropic`; caller may supply `transport`; `anthropic_streaming_model` reassembles SSE |
| Gemini model | native (transport seam) | `gemini`; caller may supply `transport`; SSE streaming |
| MCP client | native (transport seam) | `mcp_client`; base R needs caller-supplied transport for stdio |
| Harmovela sink | native | `harmovela_sink` |
| OpenTelemetry sink | native (transport seam) | `otel_sink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Retriever | native | `document`, `func_retriever`, `retriever_retrieve` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/r/examples): runnable language-specific examples.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial): scenario-oriented tutorials.
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
