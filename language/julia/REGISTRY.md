# PRAXO-CORE Julia Registry Introduction

**Status:** pending registry merge. Source version `0.5.0`, source
tag `julia/v0.5.0`. Published registry version: `0.2.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

Julia implementation of the PRAXO-CORE contract.

## Package

| Field | Value |
| --- | --- |
| Package | `PraxoCore` |
| Registry | [Julia General (pending)](https://github.com/axisvela/PraxoCore.jl) |
| Source version | `0.5.0` |
| Published registry version | `0.2.0` |
| Install (published) | `Pkg.add("PraxoCore")` |
| Install (source/release prepared) | `Pkg.add(name="PraxoCore", version="0.5.0")` |
| Source tag | `julia/v0.5.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/julia/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `OpenAICompatibleModel` |
| Anthropic model | native | `AnthropicModel`; injectable transport |
| Gemini model | native | `GeminiModel`; injectable transport |
| MCP client | native (transport seam) | `mcp_client`; caller supplies transport |
| Harmovela sink | native | `HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `otel_sink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Retriever | native | `Document`, `FuncRetriever`, `retrieve_documents` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/julia/examples): runnable language-specific examples.
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
