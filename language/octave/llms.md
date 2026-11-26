# PRAXO-CORE GNU Octave

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core`
- registry: [Octave Packages](https://github.com/axisvela/praxo-core/releases/download/octave/v0.7.0/praxo-core-0.7.0.tar.gz)
- source_version: `0.9.0`
- published_version: `0.7.0`
- install_published: `pkg install -forge praxo-core`
- install_source: `pkg install -forge praxo-core`
- source_tag: `octave/v0.9.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/octave/

## Capabilities and Status

- OpenAI-compatible model: native (Shared `praxo.openai_compatible` implementation; SSE streaming reassembly)
- Anthropic model: native (Shared `praxo.anthropic_compatible`; `onDelta` reassembles Anthropic SSE)
- Gemini model: native (Shared `praxo.gemini_compatible`; `onDelta` reassembles Gemini SSE)
- MCP client: native (transport seam) (Shared `praxo.mcp_client` implementation)
- Harmovela sink: native (Shared `praxo.harmovela_sink`)
- OpenTelemetry sink: native (transport seam) (Shared `praxo.otel_sink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (Shared `praxo.subagent_run`; no asynchronous manager)
- Retriever: native (Shared `praxo.document` and `praxo.retrieve_documents`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/octave/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends): See the tutorial README.
  - [vibration-review](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/vibration-review): A bounded vibration-analysis tutorial. It computes FFT/RMS for normal and anomalous signals, derives a high-frequency energy ratio, and lets Core choose normal or inspection rev...
  - [water-quality](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/water-quality): A bounded pond water-quality tutorial. It computes fixed dissolved-oxygen and temperature indicators, compares oxygen with a threshold, and lets Core choose a normal or aeration...
- Reference applications: no accepted end-to-end application yet; candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

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

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
