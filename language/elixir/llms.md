# PRAXO-CORE Elixir

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Elixir, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

This is a language-specific discovery entry, not a guarantee of indexing or adoption.

## Package

- package: `praxo_core`
- registry: [Hex](https://hex.pm/packages/praxo_core/0.11.1)
- source_version: `0.11.1`
- published_version: `0.11.1`
- install_published: `{:praxo_core, "~> 0.11.1"}`
- install_source: `{:praxo_core, path: "language/elixir"}`
- source_tag: `elixir/v0.11.1`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/elixir/

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
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
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Capabilities and Status

- OpenAI-compatible model: native (`Praxo.OpenAICompatible`; `streaming_model/1` and SSE reassembly cover content, tool calls, usage, and finish reason)
- Anthropic model: native (`Praxo.Anthropic`; `streaming_model/1` reassembles Anthropic SSE)
- Gemini model: native (`Praxo.Gemini`; `streaming_model/1` reassembles Gemini SSE)
- MCP client: native (`Praxo.Mcp`; stdio, plus `Praxo.McpHttp.transport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`Praxo.HarmovelaSink`)
- OpenTelemetry sink: native (transport seam) (`Praxo.OtelSink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (`Praxo.SubagentManager`)
- Retriever: native (`Praxo.Document`, `Praxo.FuncRetriever`)

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
