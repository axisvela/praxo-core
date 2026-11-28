# PRAXO-CORE MATLAB

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for MATLAB, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

This is a language-specific discovery entry, not a guarantee of indexing or adoption.

## Package

- package: `PRAXO-CORE`
- registry: [MATLAB File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core)
- source_version: `0.9.0`
- published_version: `0.9.1`
- install_published: `File Exchange entry 185166 (0.9.1)`
- install_source: `Source checkout: language/matlab and language/matlab-octave-core (see README)`
- source_tag: `matlab/v0.9.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/matlab/

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [data-quality](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/data-quality): A bounded data-quality tutorial. It computes fixed mean/median/outlier statistics, then lets Core choose normal or outlier review. No source data is modified.
- [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends): A native MATLAB/Octave signal-analysis tutorial. The Agent has one fixed tool, `review_signal`, which computes metrics over a fixed signal and returns a structured report with an empty `mutating_actions` list. It does not read arbitrary files, execute model-provided code, change thresholds or control a device.

### Reference applications

No accepted end-to-end reference application is recorded for this language yet.

Application source is not end-to-end portfolio acceptance; read each README for scope and evidence.

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/planning/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Capabilities and Status

- OpenAI-compatible model: native (`praxo.openai_compatible` using `webwrite`; SSE streaming reassembly)
- Anthropic model: native (`praxo.anthropic_compatible`; injectable transport; `onDelta` reassembles Anthropic SSE)
- Gemini model: native (`praxo.gemini_compatible`; injectable transport; `onDelta` reassembles Gemini SSE)
- MCP client: native (transport seam) (`praxo.mcp_client`; caller supplies a function handle)
- Harmovela sink: native (`praxo.harmovela_sink`)
- OpenTelemetry sink: native (transport seam) (`praxo.otel_sink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`praxo.subagent_run`; no asynchronous manager)
- Retriever: native (`praxo.document` and `praxo.retrieve_documents`)

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
