# PRAXO-CORE C++ Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for C++, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published on xmake 0.9.0 (source 0.10.0); vcpkg and Conan submissions open. Source version `0.10.0`, source
tag `cpp/v0.10.0`. Published registry version: `0.9.0`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-cpp` |
| Registry | [xmake](https://packages.xmake.io/packages/praxo-core-cpp) |
| Source version | `0.10.0` |
| Published registry version | `0.9.0` |
| Install (published) | `xrepo install praxo-core-cpp` |
| Install (source/release prepared) | `CMake source build (see README)` |
| Source tag | `cpp/v0.10.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/cpp/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/cpp/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [bom-review](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/bom-review): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [construction-safety](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/construction-safety): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [container-yard](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/container-yard): A bounded first slice of TL-02, not a terminal operating system. It replans fixed synthetic container jobs under resource constraints and drafts a review-only schedule. No crane or AGV command, live terminal feed or throughput guarantee.
- [drone-fleet-plan](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/drone-fleet-plan): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [dubbing-plan](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/dubbing-plan): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [eda-placement](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/eda-placement): A bounded first slice of OG-05, not a foundry-valid physical-design flow. It reads a fixed synthetic placement grid and drafts a review-only placement with stated PPA proxies. No routing sign-off, foundry validation or tapeout.
- [fleet-map](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/fleet-map): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [household-robot](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/household-robot): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [industrial-edge](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge): A scoped industrial tutorial over the native MIT C++ Core. It reads one fixed `edge-100` snapshot through an application-owned `DeviceAdapter` interface and drafts an operator maintenance action. The adapter is an in-process fixture. This tutorial does not implement a real fieldbus, OPC UA, socket, device SDK, live model or device write.
- [materials-design](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/materials-design): A bounded first slice of SC-04, not a validated materials-discovery pipeline. It evaluates fixed synthetic candidate properties and drafts the next review-only simulation. No validated new material or fabrication.
- [mesh-review](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/mesh-review): A bounded first slice of MD-05, not a CAD kernel or manufacturing-certification flow. It compares fixed synthetic mesh descriptors against stated constraints and drafts a review-only design assessment. No manufacturability certification or fabrication.
- [mining-slope](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/mining-slope): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [molecule-screen](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/molecule-screen): A bounded first slice of SC-02, not drug discovery. It ranks fixed synthetic molecular descriptors under stated constraints and drafts a review-only assessment. No efficacy, toxicity, synthesis or clinical claim.
- [ocean-routing](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/ocean-routing): A bounded first slice of TL-03, not a navigation or fuel-optimization system. It compares fixed synthetic route/weather costs and drafts a review-only route. No navigation command, fuel-savings claim or CII compliance guarantee.
- [production-scheduling](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/production-scheduling): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [quant-risk](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/quant-risk): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [storyboard-previs](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/storyboard-previs): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
- [traffic-signal-plan](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/traffic-signal-plan): A bounded first slice of CT-01, not a traffic-control system. It reads fixed junction queues, drafts a review-only green-time plan and checks it against deterministic limits. No signal command, live model or city-scale simulation.

### Reference applications

- [application](https://github.com/axisvela/praxo-core/tree/main/language/cpp/application): A C++ edge integration where the agent drives the primary device-diagnosis workflow: an operator submits an incident intent, the agent reads application-owned device telemetry through a `GatewayAdapter`, diagnoses the condition, and drafts a review-only maintenance action. The agent never writes to the device.

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
| OpenAI-compatible model | native (transport seam) | `OpenAICompatible`; caller supplies HTTP and streaming transports; `OpenAICompatibleStreamTransport` reassembles SSE content, tool calls, usage, and finish reason |
| Anthropic model | native (transport seam) | `Anthropic`; caller supplies HTTP and streaming transports; Anthropic SSE reassembly |
| Gemini model | native (transport seam) | `Gemini`; caller supplies HTTP and streaming transports; Gemini SSE reassembly |
| MCP client | native (transport seam) | `McpClient`; caller supplies `McpTransport` |
| Harmovela sink | native (transport seam) | `HarmovelaSink`; caller supplies HTTP transport |
| OpenTelemetry sink | native (transport seam) | `OtelSink`; caller supplies `OtelTransport` |
| Subagent delegation | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Retriever | native | `Document`, `Retriever`, `retrieve` |

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
