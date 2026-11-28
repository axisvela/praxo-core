# PRAXO-CORE Elixir Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Elixir, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published. Source version `0.11.1`, source
tag `elixir/v0.11.1`. Published registry version: `0.11.1`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo_core` |
| Registry | [Hex](https://hex.pm/packages/praxo_core/0.11.1) |
| Source version | `0.11.1` |
| Published registry version | `0.11.1` |
| Install (published) | `{:praxo_core, "~> 0.11.1"}` |
| Install (source/release prepared) | `{:praxo_core, path: "language/elixir"}` |
| Source tag | `elixir/v0.11.1` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/elixir/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/elixir/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [aiops-rca](https://github.com/axisvela/praxo-core/tree/main/language/elixir/Tutorial/aiops-rca): Fixed trace/metric/log signals yield suspect `checkout-api` and a review-only rollback. No live telemetry or remediation.
- [community-governance](https://github.com/axisvela/praxo-core/tree/main/language/elixir/Tutorial/community-governance): Fixed issues produce four classified items and a review-only reviewer request. No GitHub API, closure or impersonation.
- [knowledge-maintenance](https://github.com/axisvela/praxo-core/tree/main/language/elixir/Tutorial/knowledge-maintenance): A bounded first slice of [OP-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an autonomous Wiki service. It diffs two fixed knowledge versions, reports changed sections and removed duplicates, and drafts a review-only revision. This uses the source Elixir Core; no network, credentials or packages beyond Elixir/OTP are required.
- [soc-correlation](https://github.com/axisvela/praxo-core/tree/main/language/elixir/Tutorial/soc-correlation): Fixed EDR/firewall events produce a critical count; one critical event selects an isolation review, clean input selects monitoring. No host blocking.

### Reference applications

- [application](https://github.com/axisvela/praxo-core/tree/main/language/elixir/application): An OTP service where the agent drives the primary incident workflow: an operator submits an incident intent, the agent searches supervised telemetry, diagnoses the suspect, and drafts a review-only remediation. The agent never executes remediation.

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
| OpenAI-compatible model | native | `Praxo.OpenAICompatible`; `streaming_model/1` and SSE reassembly cover content, tool calls, usage, and finish reason |
| Anthropic model | native | `Praxo.Anthropic`; `streaming_model/1` reassembles Anthropic SSE |
| Gemini model | native | `Praxo.Gemini`; `streaming_model/1` reassembles Gemini SSE |
| MCP client | native | `Praxo.Mcp`; stdio, plus `Praxo.McpHttp.transport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `Praxo.HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `Praxo.OtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native | `Praxo.SubagentManager` |
| Retriever | native | `Praxo.Document`, `Praxo.FuncRetriever` |

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
