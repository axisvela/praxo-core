# PRAXO-CORE Delphi / Free Pascal Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Delphi / Free Pascal, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published GitHub release assets 0.9.0; OPM listing unverified. Source version `0.9.0`, source
tag `delphi/v0.9.0`. Published registry version: `0.9.0`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `PRAXO-CORE` |
| Registry | [GitHub release (OPM listing unverified)](https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.9.0) |
| Source version | `0.9.0` |
| Published registry version | `0.9.0` |
| Install (published) | `Download 0.9.0 assets from https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.9.0` |
| Install (source/release prepared) | `Source checkout: language/delphi (see README)` |
| Source tag | `delphi/v0.9.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/delphi/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/delphi/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/delphi/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [hvac-settings](https://github.com/axisvela/praxo-core/tree/main/language/delphi/Tutorial/hvac-settings): A bounded first slice of BE-02, not a building-management system. It reads a fixed building environment and drafts a review-only settings plan using the source Delphi/Free Pascal Core. No BMS command, energy-savings claim or occupancy surveillance.
- [legacy-migration](https://github.com/axisvela/praxo-core/tree/main/language/delphi/Tutorial/legacy-migration): A bounded first slice of [SE-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an automatic production migration. It inventories fixed legacy modules and dependencies and drafts a review-only migration plan. This uses the source Delphi/Free Pascal Core; no network, credentials or additional units are required.
- [rpa-reconciliation](https://github.com/axisvela/praxo-core/tree/main/language/delphi/Tutorial/rpa-reconciliation): A bounded first slice of [OP-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a production RPA platform. It reconciles a fixed purchase order and invoice, flags a delta above the threshold, and drafts a review-only exception. No ERP connector, posting or live model is used.
- [tax-review](https://github.com/axisvela/praxo-core/tree/main/language/delphi/Tutorial/tax-review): A bounded tax-planning tutorial. It reads a fixed ledger, computes taxable income and tax due, then drafts a review-only filing. No filing is submitted and no tax advice is given.

### Reference applications

No accepted end-to-end reference application is recorded for this language yet.

Application source is not end-to-end portfolio acceptance; read each README for scope and evidence.

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `TPraxoOpenAIAdapter` with FPC HTTP transport; SSE streaming reassembly |
| Anthropic model | native | `TPraxoAnthropicAdapter`; FPC HTTP transport; `GenerateStream` reassembles Anthropic SSE |
| Gemini model | native | `TPraxoGeminiAdapter`; FPC HTTP transport; `GenerateStream` reassembles Gemini SSE |
| MCP client | native | `TPraxoMcpClient`; stdio and `TPraxoHttpMcpTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `TPraxoHarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `TPraxoOtelSink`; caller supplies `TPraxoOtelTransport` |
| Subagent delegation | native (synchronous seam) | `TPraxoSubagentManager.Run`; no asynchronous manager |
| Retriever | native | `TPraxoDocument`, `TPraxoRetriever`, `PraxoRetrieveDocuments` |

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
- Reference application sources are not end-to-end portfolio acceptance. See each
  README and the [verification evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/).

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
