# PRAXO-CORE Python Registry Introduction

**Status:** published. Source version `0.7.0`, source
tag `python/v0.7.0`. Published registry version: `0.7.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is a dependency-free Python framework for building tool-using AI agents. It provides the agent runtime, not a model or hosted service, so you keep control of your models, tools, storage, and sandboxing.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [PyPI](https://pypi.org/project/praxo-core/0.7.0/) |
| Source version | `0.7.0` |
| Published registry version | `0.7.0` |
| Install (published) | `pip install praxo-core==0.7.0` |
| Install (source/release prepared) | `pip install ./language/python` |
| Source tag | `python/v0.7.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/python/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `praxo.adapters.openaicompat` |
| Anthropic model | native | `praxo.adapters.anthropic.AnthropicModel` |
| Gemini model | native | `praxo.adapters.gemini.GeminiModel` |
| MCP client | native | `praxo.adapters.mcp.MCPClient`; stdio, plus `mcp_http.StreamableHTTPTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `praxo.adapters.harmovela.HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `praxo.adapters.otel.OtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native | `praxo.delegation.SubagentManager` |
| Retriever | native | `praxo.retriever.Document` and `Retriever` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/python/examples): runnable language-specific examples.
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
