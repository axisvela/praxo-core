# PRAXO-CORE Java

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `com.axisvela:praxo-core`
- registry: [Maven Central](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.2/)
- source_version: `0.12.2`
- published_version: `0.12.2`
- install_published: `Maven: com.axisvela:praxo-core:0.12.2`
- install_source: `Maven source build (see README)`
- source_tag: `java/v0.12.2`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/java/

## Capabilities and Status

- OpenAI-compatible model: native (`adapters.OpenAICompatibleModel`)
- Anthropic model: native (`adapters.AnthropicModel`; SSE streaming reassembly)
- Gemini model: native (`adapters.GeminiModel`; SSE streaming)
- MCP client: native (`adapters.McpClient`; stdio, plus `McpStreamableHttpTransport` for Streamable HTTP 2025-03-26 (local runtime verification pending))
- Harmovela sink: native (`adapters.HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`adapters.OtelSink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (`agent.delegation.SubagentManager`)
- Retriever: native (`retriever.Document` and `Retriever`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/java/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [airport-recovery](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/airport-recovery): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [api-orchestration](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/api-orchestration): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [architecture-graph](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/architecture-graph): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [budget-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/budget-review): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [clinical-guidelines](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/clinical-guidelines): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [container-yard](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/container-yard): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [credit-diligence](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/credit-diligence): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [customs-reroute](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/customs-reroute): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [due-diligence](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/due-diligence): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [legacy-migration](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/legacy-migration): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [medical-coding](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/medical-coding): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [order-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review): This tutorial embeds the native Java Core in a loopback HTTP application. It uses the same synthetic business service as Python and TypeScript, not a shared remote Agent. The in...
  - [patent-fto](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/patent-fto): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [precedent-outline](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/precedent-outline): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [public-approval](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/public-approval): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [rpa-reconciliation](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/rpa-reconciliation): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [supply-disruption](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/supply-disruption): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [tax-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/tax-review): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [tender-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/tender-review): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [test-generation](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/test-generation): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [trial-screening](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/trial-screening): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [wealth-service](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service): A native Java Core tutorial for a review-only wealth workflow. The Agent has two fixed tools: `read_portfolio` reads synthetic account `acct-100`, and `draft_rebalance` produces...
  - [zero-trust-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/zero-trust-review): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
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
