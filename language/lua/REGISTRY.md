# PRAXO-CORE Lua Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Lua, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published; split repository v0.9.1 tagged. Source version `0.9.1-1`, source
tag `lua/v0.9.1`. Published registry version: `0.9.1-1`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [LuaRocks](https://luarocks.org/modules/hanhhuiwen/praxo-core) |
| Source version | `0.9.1-1` |
| Published registry version | `0.9.1-1` |
| Install (published) | `luarocks install praxo-core 0.9.1-1` |
| Install (source/release prepared) | `luarocks make language/lua/praxo-core-0.9.1-1.rockspec` |
| Source tag | `lua/v0.9.1` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/lua/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/lua/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [aquaculture-water](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/aquaculture-water): A bounded first slice of AE-03, not a pond-control system. It computes fixed oxygen and temperature indicators and drafts a review-only bounded action. No aerator or feeder commands, actuator access or live model.
- [host-embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding): A native Lua Core tutorial for embedding an Agent inside an existing host. The host receives a device event, exposes two fixed callbacks, and receives a review-only report. It does not send a device command, open a socket or require a model endpoint.
- [irrigation-plan](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/irrigation-plan): A bounded first slice of IN-06, not an irrigation controller. It evaluates fixed soil/weather observations and drafts a review-only bounded irrigation request. No valve command, drone dispatch or actuator access.
- [live-show](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/live-show): A bounded first slice of MD-07, not a live-stream controller. It replays fixed synthetic engagement events and drafts a review-only presentation order. No audience profiling, coupon sends or stream control.
- [storyboard-previs](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/storyboard-previs): A bounded first slice of MD-01, not a virtual-production pipeline. It reads one fixed script scene, drafts a review-only shot plan and records zero renders and zero engine calls. No Unreal integration, media generation or licensed assets.
- [world-economy](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/world-economy): A bounded first slice of MD-03, not an open-world simulation engine. It reads a fixed synthetic world economy at one tick and drafts a review-only balance with no applied change. No scale, equilibrium or long-term stability guarantee.

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
| OpenAI-compatible model | native | `praxo.openai_compatible`; `stream` reassembles SSE content, tool calls, usage, and finish reason |
| Anthropic model | native | `praxo.adapters.anthropic`; `stream` reassembles Anthropic SSE |
| Gemini model | native | `praxo.adapters.gemini`; `stream` reassembles Gemini SSE |
| MCP client | native (transport seam) | `praxo.adapters.mcp`; caller supplies transport |
| Harmovela sink | native | `praxo.harmovela_sink` |
| OpenTelemetry sink | native (transport seam) | `adapters.otel_sink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Retriever | native | `document`, `func_retriever`, `retriever_retrieve` |

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
