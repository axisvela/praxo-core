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
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial): scenario-oriented tutorials.
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
