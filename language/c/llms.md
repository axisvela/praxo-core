# PRAXO-CORE C

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for C, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

This is a language-specific discovery entry, not a guarantee of indexing or adoption.

## Package

- package: `praxo-core-c`
- registry: [xmake](https://packages.xmake.io/packages/praxo-core)
- source_version: `0.14.0`
- published_version: `0.13.0`
- install_published: `xrepo install praxo-core`
- install_source: `CMake source build (see README)`
- source_tag: `c/v0.14.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/c/

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/c/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [aquaculture-water](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/aquaculture-water): Computes fixed oxygen/temperature indicators and drafts a bounded review action. No aerator or feeder command.
- [device-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/device-diagnostics): A scoped device tutorial over the native MIT C Core. It reads one fixed `device-100` diagnostic snapshot through an application-owned `PxDeviceAdapter` function pointer and drafts an operator review action. The adapter is an in-process fixture. This tutorial does not implement a real serial bus, socket, device SDK, live model or device write.
- [hvac-settings](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/hvac-settings): Reads fixed building conditions and drafts review-only HVAC/lighting settings. No BMS command or verified energy savings.
- [lab-loop](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/lab-loop): Simulates one fixed parameter/result cycle and drafts review-only next parameters. No actuator, chemical handling or autonomous experiment.
- [livestock-monitor](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/livestock-monitor): Summarizes fixed animal observations and drafts a review-only veterinary request. No diagnosis, isolation or feeding control.
- [npc-narrative](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/npc-narrative): Reads fixed character state and drafts one scoped host action with an observed result. No arbitrary host commands.
- [world-economy](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/world-economy): Simulates one fixed economy tick and drafts a review-only balance action. No long-term equilibrium or scale guarantee.

### Reference applications

No accepted end-to-end reference application is recorded for this language yet.

Application source is not end-to-end portfolio acceptance; read each README for scope and evidence.

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Capabilities and Status

- OpenAI-compatible model: native (transport seam) (`PxOpenAICompatible`; caller supplies HTTP transport; `px_openai_generate_stream` reassembles SSE content, tool calls, usage, and finish reason)
- Anthropic model: native (transport seam) (`PxAnthropic`; caller supplies HTTP transport; `px_anthropic_generate_stream` reassembles Anthropic SSE)
- Gemini model: native (transport seam) (`PxGemini`; caller supplies HTTP transport; `px_gemini_generate_stream` reassembles Gemini SSE)
- MCP client: native (transport seam) (`PxMcpClient`; caller supplies `PxMcpTransport`)
- Harmovela sink: native (transport seam) (`praxo_harmovela`; caller supplies HTTP transport)
- OpenTelemetry sink: native (transport seam) (`PxOtelSink`; caller supplies `PxOtelTransport`)
- Subagent delegation: native (synchronous seam) (`px_subagent_run`; no asynchronous manager)
- Retriever: native (`PxDocument`, `PxRetriever`, `px_retrieve`)

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
