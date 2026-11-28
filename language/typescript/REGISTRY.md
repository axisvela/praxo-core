# PRAXO-CORE TypeScript Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for TypeScript, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published. Source version `0.10.1`, source
tag `typescript/v0.10.1`. Published registry version: `0.10.1`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `@axisvela/praxo-core` |
| Registry | [npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.10.1) |
| Source version | `0.10.1` |
| Published registry version | `0.10.1` |
| Install (published) | `npm install @axisvela/praxo-core@0.10.1` |
| Install (source/release prepared) | `npm install ./language/typescript` |
| Source tag | `typescript/v0.10.1` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/typescript/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/typescript/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [api-orchestration](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/api-orchestration): A bounded first slice of [SE-08](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an integration platform. It maps two fixed synthetic APIs, validates the order schema, and either drafts a review-only mapping or stops on a schema mismatch. No network, credentials or partner system is accessed.
- [copyright-evidence](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/copyright-evidence): Compares fixed authorized assets and drafts a review-only evidence packet. No broad crawl, DMCA notice or infringement verdict.
- [customer-support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support): A native TypeScript Core tutorial for a customer-support reply streamed over SSE. The Agent has two fixed tools: `lookup_order` reads `order-100`, and `search_policy` reads a fixed public shipping policy. The deterministic model returns an answer with a document citation; it does not send a reply, change an order or issue a refund.
- [education-tutoring](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/education-tutoring): Tracks a fixed learner fixture and drafts a graded Socratic question for review. No adaptive model or issued grade.
- [live-show](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/live-show): Replays fixed engagement events and drafts a review-only running order. No audience profiling, coupon sends or stream control.
- [localization-draft](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/localization-draft): A bounded first slice of [CS-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a legal or tax compliance system. It compares fixed localization rules and drafts review-only localized product text. No legal/tax guarantee, live content system or publication.
- [meeting-coordination](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/meeting-coordination): Reconciles fixed calendar evidence and drafts review-only minutes. No invitations or live calendar writes.
- [negotiation-interpretation](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/negotiation-interpretation): A bounded first slice of [OG-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an interpreter or cultural-profiling system. It compares a fixed bilingual transcript excerpt and drafts review-only negotiation notes. No micro-expression inference, mind reading or live interpretation guarantee.
- [order-review](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review): First deterministic native TypeScript Core integration slice. It shares the synthetic order HTTP service with the Python example, not a remote Agent loop. The `review_order` tool reads an order and creates a draft; final arguments are restricted to `order-100` by Agent policy and checked again by service scope.
- [phishing-awareness](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/phishing-awareness): Classifies a fixed synthetic email and drafts an authorized review-only awareness exercise. No sends, links or infrastructure attacks.
- [retail-replenishment](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/retail-replenishment): A bounded first slice of [CS-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not live pricing or procurement. It checks a fixed SKU's stock and pricing fixture and drafts a review-only purchase order. No network, credentials or live model are used.
- [sales-crm](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/sales-crm): Extracts fixed objections from a transcript and drafts a review-only CRM update. No CRM write or customer message.
- [storyboard-previs](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/storyboard-previs): Turns a fixed script scene into a review-only shot plan. No rendering or virtual-production engine.
- [travel-booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking): A native TypeScript Core tutorial for review-only flight booking. It checks fixed `trip-100` inventory and drafts a fare hold with no payment or booking write. The model packages computed evidence into a JSON report. This tutorial does not pay, ticket, change inventory, read arbitrary data or call a live model.
- [workspace-plan](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/workspace-plan): A bounded first slice of [SE-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a code-generation or deployment product. It reads a fixed allowlisted workspace, applies one bounded edit to `app.js` and inspects synthetic diagnostics. In-process fixtures only; no host filesystem, compiler or deployment.

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
| OpenAI-compatible model | native | `src/adapters/openaicompat.ts` |
| Anthropic model | native | `src/adapters/anthropic.ts`; SSE streaming reassembly |
| Gemini model | native | `src/adapters/gemini.ts`; SSE streaming |
| MCP client | native | `src/adapters/mcp.ts`; stdio, plus `src/adapters/mcp-http.ts` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `src/adapters/harmovela.ts` |
| OpenTelemetry sink | native (transport seam) | `src/adapters/otel.ts`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native | `src/delegation.ts` `SubagentManager` |
| Retriever | native | `src/retriever.ts` `Document` and `Retriever` |

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
