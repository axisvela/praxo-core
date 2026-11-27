# PRAXO-CORE Dart Registry Introduction

**Status:** published. Source version `0.8.1`, source
tag `dart/v0.8.1`. Published registry version: `0.8.1`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native Dart Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, OTel and Harmovela sinks, MCP, retriever and synchronous delegation seams, JSON Schema validation, and plugin manifest parsing. It runs in-process and does not require a hosted service.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo_core` |
| Registry | [pub.dev](https://pub.dev/packages/praxo_core/versions/0.8.1) |
| Source version | `0.8.1` |
| Published registry version | `0.8.1` |
| Install (published) | `dart pub add praxo_core:0.8.1` |
| Install (source/release prepared) | `dart pub add praxo_core --path language/dart` |
| Source tag | `dart/v0.8.1` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/dart/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `OpenAiCompatibleModel` with sync and async transport paths; `generateStream` reassembles SSE content, tool calls, usage, and finish reason |
| Anthropic model | native | `AnthropicModel` with sync and async transport paths; `generateStream` reassembles Anthropic SSE |
| Gemini model | native | `GeminiModel`; `generateStream` reassembles Gemini SSE |
| MCP client | native | `McpClient`; stdio, plus `McpStreamableHttpTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `OtelSink`; caller supplies `OtelTransport` |
| Subagent delegation | native (synchronous seam) | `SubagentManager.run`; no asynchronous manager |
| Retriever | native | `Document`, `FuncRetriever`, `retrieveDocuments` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/dart/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [audiobook-production](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/audiobook-production): A bounded first slice of [MD-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an audio-production pipeline. It reads a fixed licensed book fixture and drafts a review-only production plan with character and mixing cues. No synthesized audio, voice cloning or rights guarantee.
  - [cbt-exercise](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/cbt-exercise): A bounded first slice of [HC-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a therapist or crisis service. It walks a fixed synthetic CBT exercise, keeps an explicit `human_review` escalation branch and drafts a review-only summary. No live session, diagnosis, therapist replacement or unsupervised crisis handling.
  - [chronic-care](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/chronic-care): A bounded first slice of [HC-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a clinical decision system. It summarizes fixed synthetic wearable trends and routes a review-only care alert. No dosage change, individualized treatment change or live device feed.
  - [digital-twin-memory](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/digital-twin-memory): A bounded first slice of [OG-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a personal memory hub. It stores one consent-scoped synthetic memory, recalls only that scope and confirms deletion. No real inbox, passwords, cross-app access or unrestricted recall.
  - [marketing-segments](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/marketing-segments): Fixed customer spend produces two high-value customers and a review-only campaign draft. No customer records, sends or live model.
  - [meeting-coordination](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/meeting-coordination): A bounded first slice of [OP-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not full multi-party scheduling or calendar control. It reads a fixed calendar fixture, checks conflicts, and drafts review-only minutes and tasks. This uses the source Dart Core with a relative import; no network, credentials or packages are required.
  - [onboarding-plan](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/onboarding-plan): A bounded first slice of [OP-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an HR or permissions system. It reads a fixed employee profile and drafts a review-only learning path. No account provisioning, permissions or live model are used.
  - [travel-booking](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/travel-booking): Fixed trip inventory produces a review-only fare hold. No payment, ticketing or inventory write.
  - [waste-collection](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/waste-collection): A bounded first slice of [CT-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a fleet-dispatch system. It reads a fixed collection queue and drafts a review-only schedule under vehicle limits. No vehicle commands, live telemetry or live model.
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
