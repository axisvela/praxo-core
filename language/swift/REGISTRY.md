# PRAXO-CORE Swift Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Swift, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published; split repository v0.9.0 tagged; SPI re-index pending. Source version `0.9.0`, source
tag `swift/v0.9.0`. Published registry version: `0.7.2`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-swift` |
| Registry | [Swift Package Index](https://swiftpackageindex.com/axisvela/praxo-core-swift) |
| Source version | `0.9.0` |
| Published registry version | `0.7.2` |
| Install (published) | `.package(url: "https://github.com/axisvela/praxo-core-swift.git", exact: "0.7.2")` |
| Install (source/release prepared) | `.package(path: "language/swift")` |
| Source tag | `swift/v0.9.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/swift/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/swift/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/swift/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [audiobook-production](https://github.com/axisvela/praxo-core/tree/main/language/swift/Tutorial/audiobook-production): A bounded tutorial slice over the native Swift Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [cbt-exercise](https://github.com/axisvela/praxo-core/tree/main/language/swift/Tutorial/cbt-exercise): A bounded tutorial slice over the native Swift Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [chronic-care](https://github.com/axisvela/praxo-core/tree/main/language/swift/Tutorial/chronic-care): A bounded first slice of HC-02, not a clinical decision system. It summarizes fixed wearable trends, routes a review-only care alert and records no dosage or treatment change. No device SDK, patient identity or live model is used.
- [digital-twin-memory](https://github.com/axisvela/praxo-core/tree/main/language/swift/Tutorial/digital-twin-memory): A bounded tutorial slice over the native Swift Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [dubbing-plan](https://github.com/axisvela/praxo-core/tree/main/language/swift/Tutorial/dubbing-plan): A bounded tutorial slice over the native Swift Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [meeting-coordination](https://github.com/axisvela/praxo-core/tree/main/language/swift/Tutorial/meeting-coordination): A bounded tutorial slice over the native Swift Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [onboarding-plan](https://github.com/axisvela/praxo-core/tree/main/language/swift/Tutorial/onboarding-plan): A bounded tutorial slice over the native Swift Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [sales-crm](https://github.com/axisvela/praxo-core/tree/main/language/swift/Tutorial/sales-crm): A bounded tutorial slice over the native Swift Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [travel-booking](https://github.com/axisvela/praxo-core/tree/main/language/swift/Tutorial/travel-booking): A bounded tutorial slice over the native Swift Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.

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
| OpenAI-compatible model | native | `OpenAICompatibleModel` with URLSession transport; SSE streaming reassembly |
| Anthropic model | native | `AnthropicModel` with injectable transport; `generateStream` reassembles Anthropic SSE |
| Gemini model | native | `GeminiModel` with injectable transport; `generateStream` reassembles Gemini SSE |
| MCP client | native | `McpClient`, `StdioMcpTransport`, `HttpMcpTransport`; typechecked locally, full build blocked |
| Harmovela sink | native | `HarmovelaSink` with URLSession transport |
| OpenTelemetry sink | native (transport seam) | `OtelSink`; caller supplies `OtelTransport` |
| Subagent delegation | native (synchronous seam) | `SubagentManager.run`; no asynchronous manager |
| Retriever | native | `Document`, `FuncRetriever`, `retrieveDocuments` |

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
