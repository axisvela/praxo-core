# PRAXO-CORE MATLAB Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for MATLAB, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published; MATLAB runtime unverified. Source version `0.9.0`, source
tag `matlab/v0.9.0`. Published registry version: `0.9.1`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `PRAXO-CORE` |
| Registry | [MATLAB File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core) |
| Source version | `0.9.0` |
| Published registry version | `0.9.1` |
| Install (published) | `File Exchange entry 185166 (0.9.1)` |
| Install (source/release prepared) | `Source checkout: language/matlab and language/matlab-octave-core (see README)` |
| Source tag | `matlab/v0.9.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/matlab/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/matlab/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

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
- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `praxo.openai_compatible` using `webwrite`; SSE streaming reassembly |
| Anthropic model | native | `praxo.anthropic_compatible`; injectable transport; `onDelta` reassembles Anthropic SSE |
| Gemini model | native | `praxo.gemini_compatible`; injectable transport; `onDelta` reassembles Gemini SSE |
| MCP client | native (transport seam) | `praxo.mcp_client`; caller supplies a function handle |
| Harmovela sink | native | `praxo.harmovela_sink` |
| OpenTelemetry sink | native (transport seam) | `praxo.otel_sink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `praxo.subagent_run`; no asynchronous manager |
| Retriever | native | `praxo.document` and `praxo.retrieve_documents` |

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
