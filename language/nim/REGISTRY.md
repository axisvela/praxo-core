# PRAXO-CORE Nim Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Nim, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** split repository v0.8.0 tagged; Nimble/nimpkgs re-crawl pending. Source version `0.8.0`, source
tag `nim/v0.8.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo_core` |
| Registry | [Nimble/nim-lang packages (unverified)](https://github.com/axisvela/praxo-core-nim) |
| Source version | `0.8.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `Source checkout: language/nim (see README build instructions)` |
| Source tag | `nim/v0.8.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/nim/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/nim/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/nim/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [cold-chain](https://github.com/axisvela/praxo-core/tree/main/language/nim/Tutorial/cold-chain): Computes fixed temperature excursions and drafts a review-only transfer. No refrigeration change or clinical cargo guarantee.
- [irrigation-plan](https://github.com/axisvela/praxo-core/tree/main/language/nim/Tutorial/irrigation-plan): Reads fixed soil and weather observations and drafts a bounded irrigation request. No valve, drone or actuator operation.
- [leak-localization](https://github.com/axisvela/praxo-core/tree/main/language/nim/Tutorial/leak-localization): Ranks fixed pressure anomalies and drafts a review-only inspection. No valve isolation or field dispatch.
- [livestock-monitor](https://github.com/axisvela/praxo-core/tree/main/language/nim/Tutorial/livestock-monitor): Summarizes fixed animal observations and drafts a review request. No veterinary diagnosis, isolation or feeding control.
- [maintenance-triage](https://github.com/axisvela/praxo-core/tree/main/language/nim/Tutorial/maintenance-triage): A bounded first slice of [IN-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a predictive-maintenance model. It reads fixed sensor telemetry for one device, marks the indicator elevated, and drafts a review-only work order. This uses the source Nim Core; no network, credentials or packages beyond Nim and a C compiler are required.

### Reference applications

No accepted end-to-end reference application is recorded for this language yet.

Application source is not end-to-end portfolio acceptance; read each README for scope and evidence.

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/planning/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `praxo/adapters/openai_compatible`; SSE streaming reassembly |
| Anthropic model | native | `newAnthropicCompatible`; injectable transport; `generateStream` reassembles Anthropic SSE |
| Gemini model | native | `newGeminiCompatible`; injectable transport; `generateStream` reassembles Gemini SSE |
| MCP client | native (transport seam) | `praxo/adapters/mcp`; caller supplies transport |
| Harmovela sink | native | `newHarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `newOtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `subagentRun`; no asynchronous manager |
| Retriever | native | `Document`, `Retriever`, `FuncRetriever`, `retrieveDocuments` |

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
- Reference application sources are not end-to-end portfolio acceptance. See each
  README and the [verification evidence](https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/).

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
