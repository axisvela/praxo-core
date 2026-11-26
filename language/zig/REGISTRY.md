# PRAXO-CORE Zig Registry Introduction

**Status:** source-only. Source version `0.9.0`, source
tag `zig/v0.9.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

Zig 0.17 implementation of the PRAXO-CORE AI agent framework contract. The normative contract is [`spec/`](../../spec/README.md); Go remains the reference implementation.

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

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/zig/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [drone-fleet-plan](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/drone-fleet-plan): A bounded first slice of TL-01, not an airspace or flight-control system. It reads fixed drone waypoint state, drafts a review-only waypoint plan and flags a conflict zone for a...
  - [gateway-health](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health): A scoped edge tutorial over the native MIT Zig Core. It reads one fixed `gateway-100` health snapshot through an application-owned `GatewayAdapter` function table and drafts an...
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
