# PRAXO-CORE Objective-C Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Objective-C, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** source-only. Source version `0.8.0`, source
tag `objc/v0.8.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-objc` |
| Registry | Source |
| Source version | `0.8.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `See README/SETUP.md` |
| Source tag | `objc/v0.8.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/objc/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/objc/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/objc/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [chronic-care](https://github.com/axisvela/praxo-core/tree/main/language/objc/Tutorial/chronic-care): Summarizes a fixed wearable trend and drafts a review-only care alert. No dosage or individualized treatment change.
- [digital-twin-memory](https://github.com/axisvela/praxo-core/tree/main/language/objc/Tutorial/digital-twin-memory): Recalls fixed consent-scoped memories with provenance, then deletes one scope. No real inbox, passwords or unrestricted recall.
- [dlp-redaction](https://github.com/axisvela/praxo-core/tree/main/language/objc/Tutorial/dlp-redaction): Inspects a fixed export for sensitive fields and drafts a review-only redaction. No encryption, DLP completeness or sharing claim.
- [privacy-agent](https://github.com/axisvela/praxo-core/tree/main/language/objc/Tutorial/privacy-agent): A bounded first slice of [PE-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a password manager or data-deletion service. It classifies a fixed message fixture for sensitive exposure and drafts a review-only deletion request. This uses the source Objective-C Core; no network, credentials or additional frameworks beyond Foundation are required.

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
| OpenAI-compatible model | native | `PXROpenAIGenerate` with injectable transport; SSE streaming reassembly |
| Anthropic model | native | `PXRAnthropicGenerate` with injectable transport; `PXRAnthropicGenerateStream` reassembles Anthropic SSE |
| Gemini model | native | `PXRGeminiGenerate` with injectable transport; `PXRGeminiGenerateStream` reassembles Gemini SSE |
| MCP client | native | `PXRMcpClient`; stdio and `PXRHttpMcpTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `PraxoHarmovela` |
| OpenTelemetry sink | native (transport seam) | `PXROtelSink`; caller supplies `PXROtelTransport` |
| Subagent delegation | native (synchronous seam) | `PXRSubagentRun`; no asynchronous manager |
| Retriever | native | `PXDocument`, `PXRetriever`, `PXRetrieveDocuments` |

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
