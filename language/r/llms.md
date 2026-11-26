# PRAXO-CORE R

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxocore`
- registry: [r-universe](https://axisvela.r-universe.dev/praxocore)
- source_version: `0.12.0`
- published_version: `0.11.0`
- install_published: `install.packages("praxocore", repos = "https://axisvela.r-universe.dev")`
- install_source: `install.packages("praxocore", repos = "https://axisvela.r-universe.dev")`
- source_tag: `r/v0.12.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/r/

## Capabilities and Status

- OpenAI-compatible model: native (`openai_compatible` adapter; `openai_compatible_streaming_model` reassembles SSE content, tool calls, usage, and finish reason)
- Anthropic model: native (transport seam) (`anthropic`; caller may supply `transport`; `anthropic_streaming_model` reassembles SSE)
- Gemini model: native (transport seam) (`gemini`; caller may supply `transport`; SSE streaming)
- MCP client: native (transport seam) (`mcp_client`; base R needs caller-supplied transport for stdio)
- Harmovela sink: native (`harmovela_sink`)
- OpenTelemetry sink: native (transport seam) (`otel_sink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`subagent_run`; no asynchronous manager)
- Retriever: native (`document`, `func_retriever`, `retriever_retrieve`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/r/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [budget-review](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/budget-review): A bounded first slice of CT-07, not an official audit. It computes budget execution for a fixed synthetic programme, explains a flagged variance and drafts a review-only perform...
  - [clinical-guidelines](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/clinical-guidelines): Retrieves fixed guideline citations and abstains when evidence is missing. No diagnosis or treatment decision.
  - [compliance-tracking](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/compliance-tracking): Compares fixed policy versions and drafts review-only remediation. No audit conclusion or submission.
  - [data-quality](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality): A native R analytics tutorial. The Agent has one fixed tool, `summarize_dataset`, which computes statistics over a synthetic data frame. The deterministic model returns the comp...
  - [executive-brief](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/executive-brief): Computes fixed metric deltas and cites them. No causal attribution or action.
  - [fire-spread](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/fire-spread): A bounded first slice of AE-02, not a fire-warning or dispatch system. It computes fixed weather/fuel spread indicators in native R and drafts a review-only spread report. No op...
  - [hedge-plan](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/hedge-plan): A bounded first slice of AE-04, not a trading or financial-advice system. It computes fixed farm exposure and scenario margins in native R and drafts a review-only hedging plan....
  - [marketing-segmentation](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/marketing-segmentation): A native R Core tutorial for campaign segmentation. It computes per-segment statistics over a fixed customer fixture, identifies the highest-value segment, and drafts a review-o...
  - [pollution-tracing](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/pollution-tracing): Compares fixed sensor and wind records and drafts investigation hypotheses. No causal or enforcement finding.
  - [property-forecast](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/property-forecast): A bounded first slice of BE-05, not a valuation or investment-advice system. It computes fixed site metrics in native R, shows forecast assumptions and drafts a review-only fore...
  - [wealth-analysis](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/wealth-analysis): A native R Core tutorial for review-only portfolio analysis. It computes weighted risk and concentration over a fixed `acct-100` fixture, recommends a rebalance, and drafts a re...
  - [weather-anomaly](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/weather-anomaly): A bounded first slice of SC-05, not an operational forecast or warning service. It computes fixed time-series anomalies in native R and drafts a review-only notice. No operation...
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
