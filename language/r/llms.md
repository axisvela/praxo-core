# PRAXO-CORE R

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for R, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

This is a language-specific discovery entry, not a guarantee of indexing or adoption.

## Package

- package: `praxocore`
- registry: [r-universe](https://axisvela.r-universe.dev/praxocore)
- source_version: `0.12.0`
- published_version: `0.12.0`
- install_published: `install.packages("praxocore", repos = "https://axisvela.r-universe.dev")`
- install_source: `R CMD INSTALL language/r`
- source_tag: `r/v0.12.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/r/

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/r/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [budget-review](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/budget-review): A bounded first slice of CT-07, not an official audit. It computes budget execution for a fixed synthetic programme, explains a flagged variance and drafts a review-only performance finding. No real disbursement data, official audit conclusion or live model.
- [clinical-guidelines](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/clinical-guidelines): Retrieves fixed guideline citations and abstains when evidence is missing. No diagnosis or treatment decision.
- [compliance-tracking](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/compliance-tracking): Compares fixed policy versions and drafts review-only remediation. No audit conclusion or submission.
- [data-quality](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality): A native R analytics tutorial. The Agent has one fixed tool, `summarize_dataset`, which computes statistics over a synthetic data frame. The deterministic model returns the computed values as a structured report instead of inventing numbers. It does not read arbitrary files, run SQL, execute shell commands or change the dataset.
- [executive-brief](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/executive-brief): Computes fixed metric deltas and cites them. No causal attribution or action.
- [fire-spread](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/fire-spread): A bounded first slice of AE-02, not a fire-warning or dispatch system. It computes fixed weather/fuel spread indicators in native R and drafts a review-only spread report. No operational warning, evacuation order or firebreak dispatch.
- [hedge-plan](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/hedge-plan): A bounded first slice of AE-04, not a trading or financial-advice system. It computes fixed farm exposure and scenario margins in native R and drafts a review-only hedging plan. No futures orders, price lock or advice.
- [marketing-segmentation](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/marketing-segmentation): A native R Core tutorial for campaign segmentation. It computes per-segment statistics over a fixed customer fixture, identifies the highest-value segment, and drafts a review-only invite for that segment. The model packages computed evidence rather than inventing segments. This tutorial does not send messages, launch a campaign, read arbitrary data, install packages or call a live model.
- [pollution-tracing](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/pollution-tracing): Compares fixed sensor and wind records and drafts investigation hypotheses. No causal or enforcement finding.
- [property-forecast](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/property-forecast): A bounded first slice of BE-05, not a valuation or investment-advice system. It computes fixed site metrics in native R, shows forecast assumptions and drafts a review-only forecast. No verified probability, return guarantee or personal-location profiling.
- [wealth-analysis](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/wealth-analysis): A native R Core tutorial for review-only portfolio analysis. It computes weighted risk and concentration over a fixed `acct-100` fixture, recommends a rebalance, and drafts a review-only proposal that executes no trades. The model packages computed evidence instead of inventing numbers. This tutorial does not trade, transfer cash, use market data, read arbitrary files or call a live model.
- [weather-anomaly](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/weather-anomaly): A bounded first slice of SC-05, not an operational forecast or warning service. It computes fixed time-series anomalies in native R and drafts a review-only notice. No operational forecast, warning issuance or disaster dispatch.

### Reference applications

No accepted end-to-end reference application is recorded for this language yet.

Application source is not end-to-end portfolio acceptance; read each README for scope and evidence.

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/planning/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Capabilities and Status

- OpenAI-compatible model: native (`openai_compatible` adapter; `openai_compatible_streaming_model` reassembles SSE content, tool calls, usage, and finish reason)
- Anthropic model: native (transport seam) (`anthropic`; caller may supply `transport`; `anthropic_streaming_model` reassembles SSE)
- Gemini model: native (transport seam) (`gemini`; caller may supply `transport`; SSE streaming)
- MCP client: native (transport seam) (`mcp_client`; base R needs caller-supplied transport for stdio)
- Harmovela sink: native (`harmovela_sink`)
- OpenTelemetry sink: native (transport seam) (`otel_sink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`subagent_run`; no asynchronous manager)
- Retriever: native (`document`, `func_retriever`, `retriever_retrieve`)

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
