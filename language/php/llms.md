# PRAXO-CORE PHP

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `axisvela/praxo-core`
- registry: [Packagist](https://packagist.org/packages/axisvela/praxo-core)
- source_version: `0.10.0`
- published_version: `0.10.0`
- install_published: `composer require axisvela/praxo-core:0.10.0`
- install_source: `Composer path repository: language/php`
- source_tag: `php/v0.10.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/php/

## Capabilities and Status

- OpenAI-compatible model: native (`Praxo\Core\Adapters\OpenAICompatible`; implements `StreamingModel` and reassembles SSE content, tool calls, usage, and finish reason)
- Anthropic model: native (`Praxo\Core\Adapters\Anthropic`; implements `StreamingModel` with Anthropic SSE)
- Gemini model: native (`Praxo\Core\Adapters\Gemini`; implements `StreamingModel` with Gemini SSE)
- MCP client: native (`Praxo\Core\Adapters\MCPClient`; stdio, plus `HttpMCPTransport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`Praxo\Core\Adapters\HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`OtelSink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`SubagentManager::run`; no asynchronous manager)
- Retriever: native (`Document`, `Retriever`, `FuncRetriever`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/php/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [api-orchestration](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/api-orchestration): A bounded first slice of [SE-08](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a general integration platform. It reads two synthetic upstream APIs (CRM and ERP), validates the identifier mapping, and drafts a review-only integration record. This uses the native PHP Core in source mode. No network calls, credentials, new Core APIs or additional Composer packages are required.
  - [copyright-evidence](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/copyright-evidence): A bounded first slice of [LJ-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a rights-enforcement service. It compares fixed authorized assets and drafts a review-only evidence packet. No broad crawl, automatic DMCA notice or infringement adjudication.
  - [customer-support](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/customer-support): Routes one fixed ticket and drafts a review-only billing reply. No CRM send, refund or account change.
  - [customs-reroute](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/customs-reroute): A bounded first slice of [TL-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a customs-filing system. It validates fixed document fields, compares two routes and drafts a review-only reroute. No customs filing, network access or compliance determination.
  - [internal-service-desk](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/internal-service-desk): A bounded first slice of [OP-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an identity or provisioning system. It reads a fixed employee request, classifies the risk, and drafts a review-only approval. No account changes, software installation or live model are used.
  - [lead-nurture](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/lead-nurture): A bounded first slice of [CS-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an outreach-automation product. It ranks fixed synthetic business profiles and drafts review-only opt-in outreach. No crawling, scraping or unsolicited sends.
  - [localization-draft](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/localization-draft): A bounded first slice of [CS-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a legal or tax compliance system. It compares fixed localization rules and drafts review-only localized product text. No legal/tax guarantee, live content system or publication.
  - [public-approval](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/public-approval): A bounded first slice of [CT-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a government identity or approval system. It validates a fixed application's documents and drafts parallel review tasks. No official approval, document upload or live model.
  - [recruiting-match](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/recruiting-match): Matches fixed candidates against one role and drafts a review-only shortlist. No outreach, ranking model or hiring decision.
  - [retail-replenishment](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/retail-replenishment): Computes a reorder quantity from fixed stock and drafts a review-only order. No purchase order or supplier call.
  - [tender-review](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/tender-review): A bounded first slice of [BE-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a bid-submission or collusion-detection system. It validates fixed bid qualifications and flags document similarities for review. No automatic bid submission, collusion verdict or live model.
- Reference applications:
  - [ai-editorial-studio](https://github.com/axisvela/praxo-core/tree/main/language/php/application/ai-editorial-studio): A Laravel 12 content-portal application where the agent drives the primary editorial workflow: an editor submits a brief, the agent retrieves related content, drafts an article...
  - [content-review](https://github.com/axisvela/praxo-core/tree/main/language/php/application/content-review): A Laravel 12 content portal that routes one existing draft article through a governed PRAXO-CORE agent. The agent reads the article through an application-owned content store, d...
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
