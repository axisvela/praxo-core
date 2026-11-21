# PRAXO-CORE PowerShell Registry Introduction

**Status:** published; shared C# runtime. Source version `0.8.1`, source
tag `powershell/v0.8.1`. Published registry version: `0.8.1`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its PowerShell Core: a shared-runtime wrapper over the C# Core for existing PowerShell automation that needs a model/tool loop, explicit policy and tool scope, events, memory, checkpoints, and human-in-the-loop decisions.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-ps` |
| Registry | [PowerShell Gallery](https://www.powershellgallery.com/packages/praxo-core-ps/0.8.1) |
| Source version | `0.8.1` |
| Published registry version | `0.8.1` |
| Install (published) | `Install-Module praxo-core-ps` |
| Install (source/release prepared) | `Install-Module praxo-core-ps` |
| Source tag | `powershell/v0.8.1` |
| Tier | Core (.NET) |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/powershell/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | inherited | Uses the C# Core |
| Anthropic model | inherited | Uses the C# Core |
| Gemini model | inherited | Uses the C# Core |
| MCP client | native (C# shared runtime) | `Connect-PraxoMcp`, `Get-PraxoMcpTools`, `Invoke-PraxoMcpTool`; wraps the C# MCP client and stdio/Streamable HTTP transports |
| Harmovela sink | inherited | Uses the C# Core |
| OpenTelemetry sink | inherited | Uses the C# Core |
| Subagent delegation | native (synchronous wrapper) | Reuses C# request/result/task types; no asynchronous manager |
| Retriever | inherited (wrapper) | Wraps C# `Retriever` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples): runnable language-specific examples.
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
