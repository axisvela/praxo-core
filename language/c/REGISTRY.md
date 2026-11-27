# PRAXO-CORE C Registry Introduction

**Status:** published on xmake 0.13.0 (source 0.14.0); vcpkg and Conan submissions open. Source version `0.14.0`, source
tag `c/v0.14.0`. Published registry version: `0.13.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

C11 implementation of the PRAXO-CORE Core contract with source version `0.12.0`. The normative contract is [`spec/`](../../spec/README.md); Go remains the reference implementation.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-c` |
| Registry | [xmake](https://packages.xmake.io/packages/praxo-core) |
| Source version | `0.14.0` |
| Published registry version | `0.13.0` |
| Install (published) | `xrepo install praxo-core` |
| Install (source/release prepared) | `CMake source build (see README)` |
| Source tag | `c/v0.14.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/c/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native (transport seam) | `PxOpenAICompatible`; caller supplies HTTP transport; `px_openai_generate_stream` reassembles SSE content, tool calls, usage, and finish reason |
| Anthropic model | native (transport seam) | `PxAnthropic`; caller supplies HTTP transport; `px_anthropic_generate_stream` reassembles Anthropic SSE |
| Gemini model | native (transport seam) | `PxGemini`; caller supplies HTTP transport; `px_gemini_generate_stream` reassembles Gemini SSE |
| MCP client | native (transport seam) | `PxMcpClient`; caller supplies `PxMcpTransport` |
| Harmovela sink | native (transport seam) | `praxo_harmovela`; caller supplies HTTP transport |
| OpenTelemetry sink | native (transport seam) | `PxOtelSink`; caller supplies `PxOtelTransport` |
| Subagent delegation | native (synchronous seam) | `px_subagent_run`; no asynchronous manager |
| Retriever | native | `PxDocument`, `PxRetriever`, `px_retrieve` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/c/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [aquaculture-water](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/aquaculture-water): Computes fixed oxygen/temperature indicators and drafts a bounded review action. No aerator or feeder command.
  - [device-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/device-diagnostics): A scoped device tutorial over the native MIT C Core. It reads one fixed `device-100` diagnostic snapshot through an application-owned `PxDeviceAdapter` function pointer and draf...
  - [hvac-settings](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/hvac-settings): Reads fixed building conditions and drafts review-only HVAC/lighting settings. No BMS command or verified energy savings.
  - [lab-loop](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/lab-loop): Simulates one fixed parameter/result cycle and drafts review-only next parameters. No actuator, chemical handling or autonomous experiment.
  - [livestock-monitor](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/livestock-monitor): Summarizes fixed animal observations and drafts a review-only veterinary request. No diagnosis, isolation or feeding control.
  - [npc-narrative](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/npc-narrative): Reads fixed character state and drafts one scoped host action with an observed result. No arbitrary host commands.
  - [world-economy](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/world-economy): Simulates one fixed economy tick and drafts a review-only balance action. No long-term equilibrium or scale guarantee.
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
