# PRAXO-CORE Zig Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Zig, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** source-only. Source version `0.9.0`, source
tag `zig/v0.9.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-zig` |
| Registry | Source |
| Source version | `0.9.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `Source build (see README)` |
| Source tag | `zig/v0.9.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/zig/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/zig/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/zig/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [drone-fleet-plan](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/drone-fleet-plan): A bounded first slice of TL-01, not an airspace or flight-control system. It reads fixed drone waypoint state, drafts a review-only waypoint plan and flags a conflict zone for application-owned review. No flight, avoidance or geofence command.
- [gateway-health](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health): A scoped edge tutorial over the native MIT Zig Core. It reads one fixed `gateway-100` health snapshot through an application-owned `GatewayAdapter` function table and drafts an operator review action. The adapter is an in-process fixture. This tutorial does not implement MQTT, OPC UA, a socket, a real device SDK, a live model or a device write.

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
| OpenAI-compatible model | native | `openaicompat.Adapter` with `std.http`; SSE streaming reassembly |
| Anthropic model | native | `anthropic.Adapter`; injectable transport; `generateStream` reassembles Anthropic SSE |
| Gemini model | native | `gemini.Adapter`; injectable transport; `generateStream` reassembles Gemini SSE |
| MCP client | native | `mcp.Client`; stdio and curl-backed `HttpTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `harmovela` |
| OpenTelemetry sink | native (transport seam) | `otel.Sink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `delegation.subagentRun`; no asynchronous manager |
| Retriever | native | `retriever.Document`, `retriever.Retriever`, `retriever.retrieveDocuments` |

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
