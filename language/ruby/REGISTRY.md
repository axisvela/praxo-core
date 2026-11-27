# PRAXO-CORE Ruby Registry Introduction

**Status:** published; split source repository v0.10.2 tagged. Source version `0.10.2`, source
tag `ruby/v0.10.2`. Published registry version: `0.10.2`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This gem is its native Ruby Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, and plugin manifest parsing.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [RubyGems](https://rubygems.org/gems/praxo-core/versions/0.10.2) |
| Source version | `0.10.2` |
| Published registry version | `0.10.2` |
| Install (published) | `gem install praxo-core -v 0.10.2` |
| Install (source/release prepared) | `From language/ruby: gem build praxo-core.gemspec, then gem install ./praxo-core-0.10.2.gem` |
| Source tag | `ruby/v0.10.2` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/ruby/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `Praxo::Adapters::OpenAICompatible`; `generate_stream` reassembles SSE content, tool calls, usage, and finish reason |
| Anthropic model | native | `Praxo::Adapters::Anthropic`; injectable transport; `generate_stream` reassembles Anthropic SSE |
| Gemini model | native | `Praxo::Adapters::Gemini`; injectable transport; `generate_stream` reassembles Gemini SSE |
| MCP client | native | `Praxo::Adapters::MCPClient`; stdio, plus `HttpMCPTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `Praxo::Adapters::HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `OtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native | `Delegation::SubagentManager` |
| Retriever | native | `Document`, `FuncRetriever` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [community-governance](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/community-governance): A bounded first slice of [OG-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a maintainer bot. It classifies fixed synthetic issues and drafts a review-only reviewer request. No automatic issue closure, maintainer impersonation or live GitHub access.
  - [due-diligence](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/due-diligence): A bounded first slice of [LJ-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an acquisition opinion. It reconciles fixed ownership, contract and dispute fixtures and drafts a review-only risk checklist. No verified deal conclusion, data room or live model.
  - [finops-review](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/finops-review): A bounded first slice of [SE-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not autonomous multi-cloud governance. This uses the native Ruby Core in source mode. No cloud credentials, remote services, new Core APIs or additional gems are required. Ruby must already be installed.
  - [lead-nurture](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/lead-nurture): A bounded first slice of [CS-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an outreach-automation product. It ranks fixed synthetic business profiles and drafts review-only opt-in outreach. No crawling, scraping or unsolicited sends.
  - [recruiting-match](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/recruiting-match): A bounded first slice of [OP-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an automated hiring system. It matches fixed synthetic candidates against one role and drafts a review-only shortlist. No outreach, identity checks or live model are used.
  - [retail-replenishment](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/retail-replenishment): Fixed stock, daily sales and lead-time data produce a reorder quantity (22) and a review-only purchase order. No live pricing, supplier order or inventory write.
  - [supply-chain-review](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/supply-chain-review): A bounded first slice of [CY-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a malware-detection system. It compares one fixed pinned manifest with a registry copy and proposes a reviewed version pin. No dependency update, registry write or proven tamper verdict.
  - [supply-disruption](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/supply-disruption): A fixed supplier network with a port closure yields an alternative supplier (`supplier-2`) and a review-only sourcing plan. No purchase order, supplier contact or live logistics...
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
