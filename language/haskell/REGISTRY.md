# PRAXO-CORE Haskell Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Haskell, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published. Source version `0.9.0`, source
tag `haskell/v0.9.0`. Published registry version: `0.9.0`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [Hackage](https://hackage.haskell.org/package/praxo-core-0.9.0) |
| Source version | `0.9.0` |
| Published registry version | `0.9.0` |
| Install (published) | `cabal install --lib praxo-core-0.9.0` |
| Install (source/release prepared) | `cabal build --project-dir=language/haskell` |
| Source tag | `haskell/v0.9.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/haskell/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/haskell/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/haskell/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [literature-review](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/literature-review): A bounded first slice of [SC-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not autonomous scientific discovery. It searches a fixed synthetic paper corpus, cites the top result, and drafts an explicitly unverified hypothesis. This uses the source Haskell Core through `runghc`; no network, credentials or packages are required beyond GHC.
- [policy-simulation](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/policy-simulation): A bounded first slice of OG-02, not a policy-prediction engine. It simulates a small fixed synthetic population and drafts a review-only sensitivity report using the source Haskell Core through `runghc`. No tens-of-thousands scale, external simulator or real policy prediction.
- [rule-dsl](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/rule-dsl): A bounded business-rule validation tutorial. It parses a small access-rule DSL into a typed Haskell structure, detects allow/deny conflicts and returns a counterexample. Core consumes that result and drafts a review-only revision. No rule is published or applied.
- [test-generation](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/test-generation): A bounded first slice of SE-04, not a test-execution or load-testing service. It generates three bounded tests for a fixed local fixture and records zero executions. No load target, network traffic or runtime verification.

### Reference applications

No accepted end-to-end reference application is recorded for this language yet.

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
| OpenAI-compatible model | native (transport seam) | Caller supplies `Transport`; no bundled HTTP client; SSE streaming reassembly |
| Anthropic model | native (transport seam) | `Praxo.Anthropic`; caller supplies transport; `generateAnthropicStream` reassembles Anthropic SSE |
| Gemini model | native (transport seam) | `Praxo.Gemini`; caller supplies transport; `generateGeminiStream` reassembles Gemini SSE |
| MCP client | native (transport seam) | `Praxo.Mcp`; caller supplies `McpTransport` |
| Harmovela sink | native (transport seam) | `Praxo.Harmovela`; caller supplies transport |
| OpenTelemetry sink | native (transport seam) | `Praxo.Otel`; caller supplies `OtelTransport` |
| Subagent delegation | native (synchronous seam) | `Praxo.Delegation.subagentRun`; no asynchronous manager |
| Retriever | native | `Praxo.Retriever.Document` and `Retriever` |

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
