# PRAXO-CORE Julia

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Julia, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

This is a language-specific discovery entry, not a guarantee of indexing or adoption.

## Package

- package: `PraxoCore`
- registry: [Julia General (pending)](https://github.com/axisvela/praxo-core-Julia)
- source_version: `0.9.0`
- published_version: not published
- install_published: not published
- install_source: `Pkg.develop(path="language/julia")`
- source_tag: `julia/v0.9.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/julia/

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/julia/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [airport-recovery](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/airport-recovery): Simulate fixed gate, crew and connection constraints. No production write or external system access.
- [churn-warning](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/churn-warning): Compute fixed risk signals and draft a consent-aware retention offer. No production write or external system access.
- [dispatch-review](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/dispatch-review): A bounded energy-dispatch planning tutorial. It enumerates a small two-source integer dispatch, calculates cost and unmet demand, and lets Core choose a plan-review or shortfall-review branch. No grid command is issued.
- [eda-placement](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/eda-placement): Explore a fixed placement grid and report PPA proxies. No production write or external system access.
- [emergency-route-plan](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/emergency-route-plan): Simulate fixed closures and constrained relief routes. No production write or external system access.
- [experiment-comparison](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison): A native Julia analytics tutorial. The Agent has one fixed tool, `compare_experiments`, which computes means and a delta over fixed baseline and candidate results. The deterministic model packages the computed values in a report with an empty `mutating_actions` list. It does not read arbitrary data, execute model-provided Julia code, install packages or modify the experiments.
- [fire-spread](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/fire-spread): Replay fixed weather and fuel cells and compare modeled spread. No production write or external system access.
- [hedge-plan](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/hedge-plan): Simulate fixed crop exposure and compare scenario costs. No production write or external system access.
- [hvac-settings](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/hvac-settings): Simulate fixed occupancy and thermal constraints. No production write or external system access.
- [lab-loop](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/lab-loop): Simulate a fixed cycle and draft review-only next parameters. No production write or external system access.
- [materials-design](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/materials-design): Evaluate fixed candidate properties and draft the next simulation. No production write or external system access.
- [mesh-review](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/mesh-review): Compare fixed mesh descriptors against stated constraints. No production write or external system access.
- [molecule-screen](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/molecule-screen): Rank fixed synthetic descriptors and draft a review. No production write or external system access.
- [ocean-routing](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/ocean-routing): Compare fixed route/weather costs and draft a route. No production write or external system access.
- [policy-simulation](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/policy-simulation): Simulate a small synthetic population and report sensitivity. No production write or external system access.
- [traffic-signal-plan](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/traffic-signal-plan): Simulate fixed junction queues and verify timing against limits. No production write or external system access.
- [virtual-pi](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/virtual-pi): Coordinate fixed literature, simulation and review tasks with provenance. No production write or external system access.
- [waste-collection](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/waste-collection): Replan a fixed collection queue under vehicle limits. No production write or external system access.
- [wealth-analysis](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/wealth-analysis): Compute fixed statement ratios and cite assumptions. No production write or external system access.

### Reference applications

- [application](https://github.com/axisvela/praxo-core/tree/main/language/julia/application): A native Julia analysis copilot where the agent drives the numerical workflow: load a fixed yield experiment, fit a quadratic response surface by ordinary least squares, locate a bounded optimum, and return evidence-linked interpretation. The script never publishes an experiment or changes the source data.

Application source is not end-to-end portfolio acceptance; read each README for scope and evidence.

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Capabilities and Status

- OpenAI-compatible model: native (`OpenAICompatibleModel`; `generate_stream` reassembles SSE content, tool calls, usage, and finish reason)
- Anthropic model: native (`AnthropicModel`; injectable transport; `generate_stream` reassembles Anthropic SSE)
- Gemini model: native (`GeminiModel`; injectable transport; `generate_stream` reassembles Gemini SSE)
- MCP client: native (transport seam) (`mcp_client`; caller supplies transport)
- Harmovela sink: native (`HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`otel_sink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`subagent_run`; no asynchronous manager)
- Retriever: native (`Document`, `FuncRetriever`, `retrieve_documents`)

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
