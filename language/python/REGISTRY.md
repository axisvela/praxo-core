# PRAXO-CORE Python Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Python, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published. Source version `0.11.2`, source
tag `python/v0.11.2`. Published registry version: `0.11.2`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [PyPI](https://pypi.org/project/praxo-core/0.11.2/) |
| Source version | `0.11.2` |
| Published registry version | `0.11.2` |
| Install (published) | `pip install praxo-core==0.11.2` |
| Install (source/release prepared) | `pip install ./language/python` |
| Source tag | `python/v0.11.2` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/python/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/python/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/python/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [audiobook-production](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/audiobook-production): Plans fixed licensed voices and mixing cues and drafts a review-only plan. No synthesis, rendering or rights guarantee.
- [biodiversity-alerts](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/biodiversity-alerts): A bounded first slice of [AE-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an anti-poaching dispatch system. It classifies fixed labeled observations and drafts a review-only ranger alert. No species-recognition guarantee, automatic pursuit or live model.
- [bug-repair](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/bug-repair): A bounded first slice of [SE-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an autonomous coding agent. It reproduces a seeded defect, applies a review-only patch to an in-memory fixture and reruns a fixture test. No real repository scan, test runner, commit or pull request is used.
- [cbt-exercise](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/cbt-exercise): A bounded first slice of [HC-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a therapist or crisis service. It walks a fixed synthetic CBT exercise, keeps an explicit `human_review` escalation branch, and drafts a review-only summary. No live session, diagnosis, therapist replacement or unsupervised crisis handling.
- [clinical-guidelines](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/clinical-guidelines): A bounded first slice of [HC-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not diagnosis or treatment advice. It retrieves fixed synthetic guideline excerpts, cites the top match, drafts a review-only summary, and abstains when no evidence matches. No patient records or live model are used.
- [credit-diligence](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/credit-diligence): A bounded first slice of [FC-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a credit decision or fraud adjudication system. It computes fixed ratios for one synthetic applicant and drafts a review-only memo. No bureau call, decision or live model is used.
- [dubbing-plan](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/dubbing-plan): A bounded first slice of [MD-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a dubbing or voice-cloning product. It reads fixed licensed media segments and drafts a review-only caption and timing plan. No audio synthesis, impersonation, unconsented voice cloning or verified lip-sync.
- [education-tutoring](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/education-tutoring): A native Python Core tutorial for a guided study plan. An application-owned `LessonRetriever` implements the Core `Retriever` protocol and returns typed `Document`s with metadata and scores; the agent cites the top lesson and drafts a review-only study plan. This tutorial does not read arbitrary files, create assignments, identify a student or call a live model.
- [insurance-claims](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/insurance-claims): A native Python Core tutorial for review-only claim triage. Two fixed tools read a synthetic claim file and draft a decision; the deterministic model packages the tool-computed risk and payout into a schema-validated report. `StructuredOutput` rejects a malformed report before the application sees it. This tutorial does not execute a payment, adjudicate coverage, read arbitrary files, call a live model or mutate a policy.
- [legal-compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance): A native Python Core tutorial for a compliance memo with a human-review gate. One tool searches fixed policy fixtures; a second tool publishes the memo only after the application approves the interrupt. The deterministic model packages the cited evidence. This tutorial does not read arbitrary files, call a real case system, publish to a real document store or call a live model.
- [literature-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/literature-review): Retrieves two fixed abstracts and drafts unverified hypotheses with citations. No fabricated papers or verified conclusions.
- [litigation-timeline](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/litigation-timeline): Builds a cited timeline from fixed documents and drafts a review-only examination outline. No legal advice or admissibility claim.
- [marketing-segments](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/marketing-segments): Computes fixed consent-aware segments and drafts review-only content. No publication or tracking.
- [molecule-screen](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/molecule-screen): A bounded first slice of [SC-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not drug discovery. It ranks fixed synthetic molecular descriptors under stated constraints and drafts a review-only assessment. No efficacy, toxicity, synthesis or clinical claim.
- [negotiation-interpretation](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/negotiation-interpretation): Compares fixed transcript terms, flags uncertainty and drafts review-only notes. No mind reading, micro-expression inference or live interpretation guarantee.
- [office-qa](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa): A native Python Core tutorial for office-policy Q&A with citations. The Agent has one fixed tool, `search_documents`, which searches three synthetic policy documents. The deterministic model packages the top search result and its document ID into an answer. It does not read arbitrary files, call a connector, update the documents or send email.
- [order-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review): First local integration slice, not a completed HR or Web tutorial. The native Python Core chooses a scoped `review_order` tool. The tool reads a synthetic order through HTTP and creates a deterministic resolution draft. It never changes the order or issues a refund. Recommendations are application rules; model text is not proof that the draft exists.
- [patent-fto](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/patent-fto): A bounded first slice of [LJ-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a freedom-to-operate or patentability opinion. It compares fixed synthetic claims and drafts review-only questions for counsel. No live patent search, legal advice or non-infringement conclusion.
- [pentest-lab-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/pentest-lab-review): Inventories one fixed loopback lab and drafts a review-only report. No external scanning or exploit chain.
- [phishing-awareness](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/phishing-awareness): A bounded first slice of [CY-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a mail-security product. It analyzes one fixed synthetic email and drafts a review-only awareness exercise. No deceptive sends, live inbox or infrastructure attack.
- [pollution-tracing](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/pollution-tracing): A bounded first slice of [CT-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an environmental enforcement system. It compares fixed sensor and weather records and drafts review-only investigation hypotheses. No live monitoring, causal finding or enforcement action.
- [precedent-outline](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/precedent-outline): A bounded first slice of [LJ-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not legal research or advice. It retrieves fixed synthetic precedents and drafts a cited review-only outline. No live legal database, sentencing recommendation or judicial decision.
- [recruiting-match](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/recruiting-match): A bounded first slice of [OP-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an automated hiring system. It matches fixed synthetic candidates against one role and drafts a review-only shortlist. No outreach, identity checks or live model are used.
- [threat-hunting](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/threat-hunting): Searches fixed logs and drafts a cited synthetic TTP timeline. No external intelligence or APT detection guarantee.
- [trial-screening](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/trial-screening): A bounded first slice of [HC-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not patient recruitment or eligibility adjudication. It evaluates fixed synthetic patients against trial criteria and drafts a review-only screening note. No real patient data, enrollment or live model.
- [virtual-pi](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/virtual-pi): A bounded first slice of [OG-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an autonomous research team. It coordinates three fixed literature/simulation/review tasks within one shared budget and drafts a review-only plan with provenance. No external tools, scientific-validity claim or live model.

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
| OpenAI-compatible model | native | `praxo.adapters.openaicompat` |
| Anthropic model | native | `praxo.adapters.anthropic.AnthropicModel`; SSE streaming reassembly |
| Gemini model | native | `praxo.adapters.gemini.GeminiModel`; SSE streaming |
| MCP client | native | `praxo.adapters.mcp.MCPClient`; stdio, plus `mcp_http.StreamableHTTPTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `praxo.adapters.harmovela.HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `praxo.adapters.otel.OtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native | `praxo.delegation.SubagentManager` |
| Retriever | native | `praxo.retriever.Document` and `Retriever` |

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
