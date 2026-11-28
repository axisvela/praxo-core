# PRAXO-CORE Swift

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Swift, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

This is a language-specific discovery entry, not a guarantee of indexing or adoption.

## Package

- package: `praxo-core-swift`
- registry: [Swift Package Index](https://swiftpackageindex.com/axisvela/praxo-core-swift)
- source_version: `0.9.0`
- published_version: `0.7.2`
- install_published: `.package(url: "https://github.com/axisvela/praxo-core-swift.git", exact: "0.7.2")`
- install_source: `.package(path: "language/swift")`
- source_tag: `swift/v0.9.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/swift/

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
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

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/planning/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Capabilities and Status

- OpenAI-compatible model: native (`OpenAICompatibleModel` with URLSession transport; SSE streaming reassembly)
- Anthropic model: native (`AnthropicModel` with injectable transport; `generateStream` reassembles Anthropic SSE)
- Gemini model: native (`GeminiModel` with injectable transport; `generateStream` reassembles Gemini SSE)
- MCP client: native (`McpClient`, `StdioMcpTransport`, `HttpMcpTransport`; typechecked locally, full build blocked)
- Harmovela sink: native (`HarmovelaSink` with URLSession transport)
- OpenTelemetry sink: native (transport seam) (`OtelSink`; caller supplies `OtelTransport`)
- Subagent delegation: native (synchronous seam) (`SubagentManager.run`; no asynchronous manager)
- Retriever: native (`Document`, `FuncRetriever`, `retrieveDocuments`)

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
- Reference application sources are not end-to-end portfolio acceptance.

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
