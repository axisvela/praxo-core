# PRAXO-CORE C++

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core-cpp`
- registry: [xmake](https://packages.xmake.io/packages/praxo-core-cpp)
- source_version: `0.10.0`
- published_version: `0.9.0`
- install_published: `xrepo install praxo-core-cpp`
- install_source: `CMake source build (see README)`
- source_tag: `cpp/v0.10.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/cpp/

## Capabilities and Status

- OpenAI-compatible model: native (transport seam) (`OpenAICompatible`; caller supplies HTTP and streaming transports; `OpenAICompatibleStreamTransport` reassembles SSE content, tool calls, usage, and finish reason)
- Anthropic model: native (transport seam) (`Anthropic`; caller supplies HTTP and streaming transports; Anthropic SSE reassembly)
- Gemini model: native (transport seam) (`Gemini`; caller supplies HTTP and streaming transports; Gemini SSE reassembly)
- MCP client: native (transport seam) (`McpClient`; caller supplies `McpTransport`)
- Harmovela sink: native (transport seam) (`HarmovelaSink`; caller supplies HTTP transport)
- OpenTelemetry sink: native (transport seam) (`OtelSink`; caller supplies `OtelTransport`)
- Subagent delegation: native (synchronous seam) (`subagent_run`; no asynchronous manager)
- Retriever: native (`Document`, `Retriever`, `retrieve`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [bom-review](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/bom-review): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [construction-safety](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/construction-safety): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [container-yard](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/container-yard): A bounded first slice of TL-02, not a terminal operating system. It replans fixed synthetic container jobs under resource constraints and drafts a review-only schedule. No crane...
  - [drone-fleet-plan](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/drone-fleet-plan): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [dubbing-plan](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/dubbing-plan): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [eda-placement](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/eda-placement): A bounded first slice of OG-05, not a foundry-valid physical-design flow. It reads a fixed synthetic placement grid and drafts a review-only placement with stated PPA proxies. N...
  - [fleet-map](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/fleet-map): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [household-robot](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/household-robot): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [industrial-edge](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge): A scoped industrial tutorial over the native MIT C++ Core. It reads one fixed `edge-100` snapshot through an application-owned `DeviceAdapter` interface and drafts an operator m...
  - [materials-design](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/materials-design): A bounded first slice of SC-04, not a validated materials-discovery pipeline. It evaluates fixed synthetic candidate properties and drafts the next review-only simulation. No va...
  - [mesh-review](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/mesh-review): A bounded first slice of MD-05, not a CAD kernel or manufacturing-certification flow. It compares fixed synthetic mesh descriptors against stated constraints and drafts a review...
  - [mining-slope](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/mining-slope): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [molecule-screen](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/molecule-screen): A bounded first slice of SC-02, not drug discovery. It ranks fixed synthetic molecular descriptors under stated constraints and drafts a review-only assessment. No efficacy, tox...
  - [ocean-routing](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/ocean-routing): A bounded first slice of TL-03, not a navigation or fuel-optimization system. It compares fixed synthetic route/weather costs and drafts a review-only route. No navigation comma...
  - [production-scheduling](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/production-scheduling): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [quant-risk](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/quant-risk): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [storyboard-previs](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/storyboard-previs): A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access.
  - [traffic-signal-plan](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/traffic-signal-plan): A bounded first slice of CT-01, not a traffic-control system. It reads fixed junction queues, drafts a review-only green-time plan and checks it against deterministic limits. No...
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
