# PRAXO-CORE Julia Registry Introduction

**Status:** not published; General registry PR updated to 0.9.0; merge pending; mirror 0.9.0 tagged. Source version `0.9.0`, source
tag `julia/v0.9.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

Julia implementation of the PRAXO-CORE AI agent framework contract.

## Package

| Field | Value |
| --- | --- |
| Package | `PraxoCore` |
| Registry | [Julia General (pending)](https://github.com/axisvela/PraxoCore.jl) |
| Source version | `0.9.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `Pkg.develop(path="language/julia")` |
| Source tag | `julia/v0.9.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/julia/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `OpenAICompatibleModel`; `generate_stream` reassembles SSE content, tool calls, usage, and finish reason |
| Anthropic model | native | `AnthropicModel`; injectable transport; `generate_stream` reassembles Anthropic SSE |
| Gemini model | native | `GeminiModel`; injectable transport; `generate_stream` reassembles Gemini SSE |
| MCP client | native (transport seam) | `mcp_client`; caller supplies transport |
| Harmovela sink | native | `HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `otel_sink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Retriever | native | `Document`, `FuncRetriever`, `retrieve_documents` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/julia/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [airport-recovery](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/airport-recovery): Simulate fixed gate, crew and connection constraints. No production write or external system access.
  - [churn-warning](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/churn-warning): Compute fixed risk signals and draft a consent-aware retention offer. No production write or external system access.
  - [dispatch-review](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/dispatch-review): A bounded energy-dispatch planning tutorial. It enumerates a small two-source integer dispatch, calculates cost and unmet demand, and lets Core choose a plan-review or shortfall...
  - [eda-placement](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/eda-placement): Explore a fixed placement grid and report PPA proxies. No production write or external system access.
  - [emergency-route-plan](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/emergency-route-plan): Simulate fixed closures and constrained relief routes. No production write or external system access.
  - [experiment-comparison](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison): A native Julia analytics tutorial. The Agent has one fixed tool, `compare_experiments`, which computes means and a delta over fixed baseline and candidate results. The determini...
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
