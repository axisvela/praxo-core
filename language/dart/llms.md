# PRAXO-CORE Dart

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo_core`
- registry: [pub.dev](https://pub.dev/packages/praxo_core/versions/0.7.0)
- source_version: `0.8.0`
- published_version: `0.7.0`
- install_published: `dart pub add praxo_core:^0.7.0`
- install_source: `dart pub add praxo_core:^0.7.0`
- source_tag: `dart/v0.8.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/dart/

## Capabilities and Status

- OpenAI-compatible model: native (`OpenAiCompatibleModel` with sync and async transport paths; `generateStream` reassembles SSE content, tool calls, usage, and finish reason)
- Anthropic model: native (`AnthropicModel` with sync and async transport paths; `generateStream` reassembles Anthropic SSE)
- Gemini model: native (`GeminiModel`; `generateStream` reassembles Gemini SSE)
- MCP client: native (`McpClient`; stdio, plus `McpStreamableHttpTransport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`OtelSink`; caller supplies `OtelTransport`)
- Subagent delegation: native (synchronous seam) (`SubagentManager.run`; no asynchronous manager)
- Retriever: native (`Document`, `FuncRetriever`, `retrieveDocuments`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/dart/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [audiobook-production](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/audiobook-production): A bounded first slice of [MD-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an audio-production pipeline. It reads a fixed licensed book fixtur...
  - [cbt-exercise](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/cbt-exercise): A bounded first slice of [HC-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a therapist or crisis service. It walks a fixed synthetic CBT exerc...
  - [chronic-care](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/chronic-care): A bounded first slice of [HC-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a clinical decision system. It summarizes fixed synthetic wearable...
  - [digital-twin-memory](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/digital-twin-memory): A bounded first slice of [OG-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a personal memory hub. It stores one consent-scoped synthetic memor...
  - [marketing-segments](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/marketing-segments): Fixed customer spend produces two high-value customers and a review-only campaign draft. No customer records, sends or live model.
  - [meeting-coordination](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/meeting-coordination): A bounded first slice of [OP-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not full multi-party scheduling or calendar control. It reads a fixed c...
  - [onboarding-plan](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/onboarding-plan): A bounded first slice of [OP-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an HR or permissions system. It reads a fixed employee profile and...
  - [travel-booking](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/travel-booking): Fixed trip inventory produces a review-only fare hold. No payment, ticketing or inventory write.
  - [waste-collection](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/waste-collection): A bounded first slice of [CT-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a fleet-dispatch system. It reads a fixed collection queue and draf...
- Reference applications: no accepted end-to-end application yet; candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

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

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
