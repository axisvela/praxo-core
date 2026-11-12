# PRAXO-CORE C# Registry Introduction

**Status:** published. Source version `0.6.0`, source
tag `csharp/v0.6.0`. Published registry version: `0.5.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native .NET Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, and plugin manifest parsing. It runs in-process and does not require a hosted service.

## Package

| Field | Value |
| --- | --- |
| Package | `Praxo.Core` |
| Registry | [NuGet](https://www.nuget.org/packages/Praxo.Core/0.5.0) |
| Source version | `0.6.0` |
| Published registry version | `0.5.0` |
| Install (published) | `dotnet add package Praxo.Core --version 0.5.0` |
| Install (source/release prepared) | `dotnet add package Praxo.Core --version 0.6.0` |
| Source tag | `csharp/v0.6.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/csharp/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `Praxo.Core.OpenAiCompatible` |
| Anthropic model | native | `Praxo.Core.AnthropicModel` |
| Gemini model | native | `Praxo.Core.GeminiModel` |
| MCP client | native | `Praxo.Core.Adapters.McpClient`; stdio, plus `McpStreamableHttpTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `Praxo.Core.HarmovelaSink` |

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
