# PRAXO-CORE C# Registry Introduction

**Status:** published. Source version `0.11.0`, source
tag `csharp/v0.11.0`. Published registry version: `0.10.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native .NET Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, and plugin manifest parsing. It runs in-process and does not require a hosted service.

## Package

| Field | Value |
| --- | --- |
| Package | `Praxo.Core` |
| Registry | [NuGet](https://www.nuget.org/packages/Praxo.Core/0.10.0) |
| Source version | `0.11.0` |
| Published registry version | `0.10.0` |
| Install (published) | `dotnet add package Praxo.Core --version 0.10.0` |
| Install (source/release prepared) | `ProjectReference to language/csharp/Praxo.Core` |
| Source tag | `csharp/v0.11.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/csharp/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `Praxo.Core.OpenAiCompatible` |
| Anthropic model | native | `Praxo.Core.AnthropicModel`; SSE streaming reassembly |
| Gemini model | native | `Praxo.Core.GeminiModel`; SSE streaming |
| MCP client | native | `Praxo.Core.Adapters.McpClient`; stdio, plus `McpStreamableHttpTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `Praxo.Core.HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `Praxo.Core.OtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native | `Praxo.Core.Delegation.SubagentManager` |
| Retriever | native | `Praxo.Core.Retriever.Document` and `Retriever` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [airport-recovery](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/airport-recovery): A bounded first slice of [TL-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an airport operations system. It reads fixed gate/crew/connection c...
  - [architecture-graph](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/architecture-graph): A bounded tutorial slice over the native .NET Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [bom-review](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/bom-review): A bounded tutorial slice over the native .NET Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [construction-safety](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/construction-safety): A bounded tutorial slice over the native .NET Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [contract-review](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/contract-review): A bounded tutorial slice over the native .NET Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [due-diligence](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/due-diligence): A bounded tutorial slice over the native .NET Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [healthcare-scheduling](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/healthcare-scheduling): A native C# Core tutorial for review-only appointment scheduling. It reads a fixed `appointment-100` clinic schedule, checks slot availability, and drafts a booking for human re...
  - [internal-service-desk](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/internal-service-desk): A bounded tutorial slice over the native .NET Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [medical-coding](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/medical-coding): A bounded first slice of [HC-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a billing or reimbursement system. It checks fixed record completen...
  - [order-review](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review): Embed the native C# Core in an ASP.NET Core minimal API. The Agent invokes a scoped order-review tool over the public synthetic business service. The same application also offer...
  - [phishing-awareness](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/phishing-awareness): A bounded tutorial slice over the native .NET Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [public-approval](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/public-approval): A bounded tutorial slice over the native .NET Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [rpa-reconciliation](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/rpa-reconciliation): A bounded tutorial slice over the native .NET Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [sales-crm](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/sales-crm): A native C# Core tutorial for a review-only sales workflow. The Agent has two fixed tools: `read_customer` reads synthetic customer `customer-100`, and `draft_followup` produces...
  - [test-generation](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/test-generation): A bounded first slice of [SE-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a test-execution or load-testing service. It generates three bounde...
  - [trial-screening](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/trial-screening): A bounded tutorial slice over the native .NET Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [zero-trust-review](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/zero-trust-review): A bounded tutorial slice over the native .NET Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- Reference applications: no accepted end-to-end application yet; candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
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
