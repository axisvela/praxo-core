# PRAXO-CORE Fortran Registry Introduction

**Status:** source-only. Source version `0.12.0`, source
tag `fortran/v0.12.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native Fortran 2008 Core: an in-process agent loop with tools, policy, middleware, events, checkpoints, and human-in-the-loop decisions, implemented in Fortran rather than bridged to another runtime.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-fortran` |
| Registry | Source / CMake |
| Source version | `0.12.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `Source build (see README)` |
| Source tag | `fortran/v0.12.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/fortran/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native (transport seam) | `openai_compatible`; caller supplies HTTP transport; `generate_stream` reassembles SSE content, tool calls, usage, and finish reason |
| Anthropic model | native (transport seam) | `anthropic_compatible`; caller supplies HTTP transport; `generate_stream` reassembles Anthropic SSE |
| Gemini model | native (transport seam) | `gemini_compatible`; caller supplies HTTP transport; `generate_stream` reassembles Gemini SSE |
| MCP client | native (transport seam) | `mcp_client`; caller supplies transport |
| Harmovela sink | native (transport seam) | `harmovela`; caller supplies HTTP transport |
| OpenTelemetry sink | native (transport seam) | `otel_sink`; caller supplies transport |
| Subagent delegation | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Retriever | native | `document`, `retriever`, `retrieve_documents` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [dispatch-review](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/dispatch-review): Simulates a fixed charge/discharge schedule and checks limits outside the agent. No grid command.
  - [eda-placement](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/eda-placement): Explores a fixed placement grid and reports stated proxy values. No foundry-valid layout or proven PPA optimization.
  - [fire-spread](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/fire-spread): Replays fixed fuel/weather cells and reports a modeled spread. No operational warning or firebreak dispatch.
  - [leak-localization](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/leak-localization): Ranks fixed pressure drops and drafts a review-only inspection. No valve isolation or field dispatch.
  - [mesh-review](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/mesh-review): Compares a fixed mesh descriptor against stated constraints and drafts an assessment. No manufacturability or mechanical certification.
  - [mining-slope](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/mining-slope): Computes fixed displacement indicators and drafts a review alert. No collapse prediction or vehicle dispatch.
  - [ocean-routing](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/ocean-routing): Compares fixed route and weather costs and drafts a route. No navigation, fuel-savings or CII compliance claim.
  - [pollution-tracing](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/pollution-tracing): Compares fixed sensor readings and drafts two investigation hypotheses. No causal or enforcement finding.
  - [simulation-metrics](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/simulation-metrics): A scoped numerical tutorial over the native MIT Fortran Core. It computes fixed simulation metrics through a native tool, then lets a deterministic model package the computed nu...
  - [weather-anomaly](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/weather-anomaly): Computes fixed temperature anomalies and drafts a review-only notice. No operational forecast or warning dispatch.
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
