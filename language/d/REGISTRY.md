# PRAXO-CORE D Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for D, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published; split source repository. Source version `0.8.0`, source
tag `d/v0.8.0`. Published registry version: `0.8.0`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [DUB](https://code.dlang.org/packages/praxo-core) |
| Source version | `0.8.0` |
| Published registry version | `0.8.0` |
| Install (published) | `dub add praxo-core@0.8.0` |
| Install (source/release prepared) | `dub build --root=language/d` |
| Source tag | `d/v0.8.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/d/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/d/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/d/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [data-pipeline](https://github.com/axisvela/praxo-core/tree/main/language/d/Tutorial/data-pipeline): Diagnose a bounded data-import batch before allowing a human to review it. Native D parses unquoted two-column CSV records, calculates valid totals and reports line-specific errors. Core calls the analysis tool, consumes its result and chooses either rejection review or import review. Neither path imports data.
- [executive-brief](https://github.com/axisvela/praxo-core/tree/main/language/d/Tutorial/executive-brief): A bounded first slice of [OP-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an autonomous BI platform. It computes fixed business-line variances for one period and drafts a review-only operating brief. This uses the source D Core with `dmd -run`; no network, credentials or packages beyond DMD are required.
- [fleet-map](https://github.com/axisvela/praxo-core/tree/main/language/d/Tutorial/fleet-map): A bounded first slice of TL-06, not a remote-assistance or map-deployment system. It replays fixed synthetic road-topology changes and drafts a review-only map patch. No vehicle takeover, automatic deployment or live fleet access.
- [property-forecast](https://github.com/axisvela/praxo-core/tree/main/language/d/Tutorial/property-forecast): A bounded first slice of BE-05, not a valuation or investment-advice system. It computes fixed site metrics in native D, shows the forecast assumptions and drafts a review-only forecast. No verified probability, return guarantee or personal-location profiling.
- [quant-risk](https://github.com/axisvela/praxo-core/tree/main/language/d/Tutorial/quant-risk): A bounded first slice of [FC-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a trading or execution system. It reads fixed portfolio/market data, computes proposed-order exposure, enforces a stated risk limit outside the agent, and drafts a review-only order. No trades, live market feed or latency claim.

### Reference applications

No accepted end-to-end reference application is recorded for this language yet.

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
| OpenAI-compatible model | native (transport seam) | `OpenAICompatibleModel`; caller may inject transport; SSE streaming reassembly |
| Anthropic model | native (transport seam) | `AnthropicModel`; caller may inject transport; SSE streaming reassembly |
| Gemini model | native (transport seam) | `GeminiModel`; caller may inject transport; SSE streaming |
| MCP client | native | `praxo.mcp.McpClient`; stdio, plus `HttpMcpTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `HarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `OtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `SubagentManager.run` in `praxo.delegation`; no asynchronous manager |
| Retriever | native | `Document`, `Retriever`, `FuncRetriever`, `retrieveDocuments` |

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
