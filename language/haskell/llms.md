# PRAXO-CORE Haskell

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Haskell, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

This is a language-specific discovery entry, not a guarantee of indexing or adoption.

## Package

- package: `praxo-core`
- registry: [Hackage](https://hackage.haskell.org/package/praxo-core-0.9.0)
- source_version: `0.9.0`
- published_version: `0.9.0`
- install_published: `cabal install --lib praxo-core-0.9.0`
- install_source: `cabal build --project-dir=language/haskell`
- source_tag: `haskell/v0.9.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/haskell/

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/haskell/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [literature-review](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/literature-review): A bounded first slice of [SC-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not autonomous scientific discovery. It searches a fixed synthetic paper corpus, cites the top result, and drafts an explicitly unverified hypothesis. This uses the source Haskell Core through `runghc`; no network, credentials or packages are required beyond GHC.
- [policy-simulation](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/policy-simulation): A bounded first slice of OG-02, not a policy-prediction engine. It simulates a small fixed synthetic population and drafts a review-only sensitivity report using the source Haskell Core through `runghc`. No tens-of-thousands scale, external simulator or real policy prediction.
- [rule-dsl](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/rule-dsl): A bounded business-rule validation tutorial. It parses a small access-rule DSL into a typed Haskell structure, detects allow/deny conflicts and returns a counterexample. Core consumes that result and drafts a review-only revision. No rule is published or applied.
- [test-generation](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/test-generation): A bounded first slice of SE-04, not a test-execution or load-testing service. It generates three bounded tests for a fixed local fixture and records zero executions. No load target, network traffic or runtime verification.

### Reference applications

No accepted end-to-end reference application is recorded for this language yet.

Application source is not end-to-end portfolio acceptance; read each README for scope and evidence.

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Capabilities and Status

- OpenAI-compatible model: native (transport seam) (Caller supplies `Transport`; no bundled HTTP client; SSE streaming reassembly)
- Anthropic model: native (transport seam) (`Praxo.Anthropic`; caller supplies transport; `generateAnthropicStream` reassembles Anthropic SSE)
- Gemini model: native (transport seam) (`Praxo.Gemini`; caller supplies transport; `generateGeminiStream` reassembles Gemini SSE)
- MCP client: native (transport seam) (`Praxo.Mcp`; caller supplies `McpTransport`)
- Harmovela sink: native (transport seam) (`Praxo.Harmovela`; caller supplies transport)
- OpenTelemetry sink: native (transport seam) (`Praxo.Otel`; caller supplies `OtelTransport`)
- Subagent delegation: native (synchronous seam) (`Praxo.Delegation.subagentRun`; no asynchronous manager)
- Retriever: native (`Praxo.Retriever.Document` and `Retriever`)

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
