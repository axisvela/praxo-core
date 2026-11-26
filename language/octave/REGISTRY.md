# PRAXO-CORE GNU Octave Registry Introduction

**Status:** release tarball 0.7.0 published; package index PR pending. Source version `0.9.0`, source
tag `octave/v0.9.0`. Published registry version: `0.7.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

Native Octave Core for the PRAXO-CORE agent framework. This is the independent Octave package root and source tag `octave/v0.9.0`; it shares the implementation in `language/matlab-octave-core/+praxo` with the MATLAB package. It passes all eleven shared vector groups under GNU Octave 11.3.0 and includes the native agent loop, memory store, checkpoint allowlist, lexical path policy, context compaction, event sinks, middleware helpers, tool selection, an OpenTelemetry transport-seam sink, a retriever seam, and synchronous subagent delegation. It does not delegate behavior to Go or another language Core.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [Octave Packages](https://github.com/axisvela/praxo-core/releases/download/octave/v0.7.0/praxo-core-0.7.0.tar.gz) |
| Source version | `0.9.0` |
| Published registry version | `0.7.0` |
| Install (published) | `pkg install -forge praxo-core` |
| Install (source/release prepared) | `pkg install -forge praxo-core` |
| Source tag | `octave/v0.9.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/octave/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | Shared `praxo.openai_compatible` implementation; SSE streaming reassembly |
| Anthropic model | native | Shared `praxo.anthropic_compatible`; `onDelta` reassembles Anthropic SSE |
| Gemini model | native | Shared `praxo.gemini_compatible`; `onDelta` reassembles Gemini SSE |
| MCP client | native (transport seam) | Shared `praxo.mcp_client` implementation |
| Harmovela sink | native | Shared `praxo.harmovela_sink` |
| OpenTelemetry sink | native (transport seam) | Shared `praxo.otel_sink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | Shared `praxo.subagent_run`; no asynchronous manager |
| Retriever | native | Shared `praxo.document` and `praxo.retrieve_documents` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/octave/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends): See the tutorial README.
  - [vibration-review](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/vibration-review): A bounded vibration-analysis tutorial. It computes FFT/RMS for normal and anomalous signals, derives a high-frequency energy ratio, and lets Core choose normal or inspection rev...
  - [water-quality](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/water-quality): A bounded pond water-quality tutorial. It computes fixed dissolved-oxygen and temperature indicators, compares oxygen with a threshold, and lets Core choose a normal or aeration...
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
