# PRAXO-CORE Erlang Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Erlang, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published. Source version `0.10.1`, source
tag `erlang/v0.10.1`. Published registry version: `0.10.1`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo_core_erlang` |
| Registry | [Hex](https://hex.pm/packages/praxo_core_erlang/0.10.1) |
| Source version | `0.10.1` |
| Published registry version | `0.10.1` |
| Install (published) | `{praxo_core, "0.10.1", {pkg, praxo_core_erlang}}` |
| Install (source/release prepared) | `{praxo_core, {path, "language/erlang"}}` |
| Source tag | `erlang/v0.10.1` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/erlang/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/erlang/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [aiops-rca](https://github.com/axisvela/praxo-core/tree/main/language/erlang/Tutorial/aiops-rca): A bounded first slice of [SE-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a production incident platform. It correlates fixed trace/metric/log signals and drafts a review-only rollback. This uses the source Erlang Core through `escript`; no network, credentials or packages beyond Erlang/OTP are required.
- [otp-recovery](https://github.com/axisvela/praxo-core/tree/main/language/erlang/Tutorial/otp-recovery): A bounded OTP supervision tutorial. It starts a real `one_for_one` supervisor and worker, injects one child crash, observes the restarted PID and start count, then lets Core choose a review action from that evidence. No production cluster is touched.
- [policy-simulation](https://github.com/axisvela/praxo-core/tree/main/language/erlang/Tutorial/policy-simulation): A bounded concurrent simulation: twelve Erlang processes compute household subsidies for base and alternate policies, yielding 1200 and 1800. Core drafts a review-only sensitivity report with no policy prediction.
- [soc-correlation](https://github.com/axisvela/praxo-core/tree/main/language/erlang/Tutorial/soc-correlation): Fixed EDR and firewall events are correlated; one critical event selects an isolation-review branch, while clean input selects monitoring review. No host is blocked and no live SIEM is queried.

### Reference applications

- [application](https://github.com/axisvela/praxo-core/tree/main/language/erlang/application): An OTP application where the agent drives the primary incident workflow: an operator submits an incident intent, the agent searches supervised telemetry, diagnoses the suspect, and drafts a review-only remediation. The agent never executes remediation.

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
| OpenAI-compatible model | native | `praxo_openai_compatible`; `streaming_model/1` and `generate_stream/3` reassemble SSE content, tool calls, usage, and finish reason |
| Anthropic model | native | `praxo_anthropic`; `streaming_model/1` reassembles Anthropic SSE |
| Gemini model | native | `praxo_gemini`; `streaming_model/1` reassembles Gemini SSE |
| MCP client | native | `praxo_mcp`; stdio, plus `praxo_mcp_http:transport/2` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `praxo_harmovela` |
| OpenTelemetry sink | native (transport seam) | `praxo_otel`; caller supplies transport |
| Subagent delegation | native (synchronous seam) | `praxo_delegation:subagent_run/2`; no asynchronous manager |
| Retriever | native | `praxo_retriever:document`, `func_retriever`, `retrieve/3` |

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
