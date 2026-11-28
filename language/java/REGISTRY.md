# PRAXO-CORE Java Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Java, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published. Source version `0.12.3`, source
tag `java/v0.12.3`. Published registry version: `0.12.3`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `com.axisvela:praxo-core` |
| Registry | [Maven Central](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.3/) |
| Source version | `0.12.3` |
| Published registry version | `0.12.3` |
| Install (published) | `Maven: com.axisvela:praxo-core:0.12.3` |
| Install (source/release prepared) | `Maven source build (see README)` |
| Source tag | `java/v0.12.3` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/java/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/java/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/java/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

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
- [order-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review): This tutorial embeds the native Java Core in a loopback HTTP application. It uses the same synthetic business service as Python and TypeScript, not a shared remote Agent. The initial model is deterministic: it requests `review_order`, then returns the tool result. The application computes the recommendation from order status. It does not use an LLM to decide a refund or perform business writes.
- [patent-fto](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/patent-fto): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [precedent-outline](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/precedent-outline): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [public-approval](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/public-approval): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [rpa-reconciliation](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/rpa-reconciliation): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [supply-disruption](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/supply-disruption): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [tax-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/tax-review): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [tender-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/tender-review): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [test-generation](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/test-generation): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [trial-screening](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/trial-screening): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [wealth-service](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service): A native Java Core tutorial for a review-only wealth workflow. The Agent has two fixed tools: `read_portfolio` reads synthetic account `acct-100`, and `draft_rebalance` produces a `draft_only` allocation proposal for human review. It never places a trade, transfers cash or changes a portfolio.
- [zero-trust-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/zero-trust-review): A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.

### Reference applications

- [application](https://github.com/axisvela/praxo-core/tree/main/language/java/application): A Spring Boot commerce application where the agent drives the primary shopping workflow: a customer states an intent, the agent searches the application-owned catalog, checks inventory, drafts a cart, and creates a review-only checkout request. The agent never charges, places an order, or ships.

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
| OpenAI-compatible model | native | `adapters.OpenAICompatibleModel` |
| Anthropic model | native | `adapters.AnthropicModel`; SSE streaming reassembly |
| Gemini model | native | `adapters.GeminiModel`; SSE streaming |
| MCP client | native | `adapters.McpClient`; stdio, plus `McpStreamableHttpTransport` for Streamable HTTP 2025-03-26 (local runtime verification pending) |
| Harmovela sink | native | `adapters.HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `adapters.OtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native | `agent.delegation.SubagentManager` |
| Retriever | native | `retriever.Document` and `Retriever` |

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
