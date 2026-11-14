# PRAXO-CORE Delphi / Free Pascal Registry Introduction

**Status:** source release; OPM submission pending. Source version `0.5.0`, source
tag `delphi/v0.5.0`. Published registry version: `0.2.1`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

Native Core implementation with source tag `delphi/v0.5.0`. It passes all eleven vector groups and includes the native agent loop plus memory, event, checkpoint, policy, context, and middleware helpers. It does not call Go or another language Core; it includes native OpenAI-compatible, Anthropic, and Gemini model adapters but no process bridge or plugin host.

## Package

| Field | Value |
| --- | --- |
| Package | `PRAXO-CORE` |
| Registry | [OPM / GitHub release](https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.2.1) |
| Source version | `0.5.0` |
| Published registry version | `0.2.1` |
| Install (published) | `OPM package or release archive` |
| Install (source/release prepared) | `OPM package or release archive` |
| Source tag | `delphi/v0.5.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/delphi/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `TPraxoOpenAIAdapter` with FPC HTTP transport |
| Anthropic model | native | `TPraxoAnthropicAdapter`; FPC HTTP transport |
| Gemini model | native | `TPraxoGeminiAdapter`; FPC HTTP transport |
| MCP client | native | `TPraxoMcpClient`; stdio and `TPraxoHttpMcpTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `TPraxoHarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `TPraxoOtelSink`; caller supplies `TPraxoOtelTransport` |
| Subagent delegation | native (synchronous seam) | `TPraxoSubagentManager.Run`; no asynchronous manager |
| Retriever | native | `TPraxoDocument`, `TPraxoRetriever`, `PraxoRetrieveDocuments` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/delphi/examples): runnable language-specific examples.
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
