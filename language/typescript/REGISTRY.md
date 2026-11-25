# PRAXO-CORE TypeScript Registry Introduction

**Status:** published. Source version `0.10.0`, source
tag `typescript/v0.10.0`. Published registry version: `0.9.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is a dependency-free TypeScript framework for building tool-using AI agents. It provides the agent runtime, not a model or hosted service, so you keep control of your models, tools, storage, and sandboxing.

## Package

| Field | Value |
| --- | --- |
| Package | `@axisvela/praxo-core` |
| Registry | [npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.9.0) |
| Source version | `0.10.0` |
| Published registry version | `0.9.0` |
| Install (published) | `npm install @axisvela/praxo-core@0.9.0` |
| Install (source/release prepared) | `npm install ./language/typescript` |
| Source tag | `typescript/v0.10.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/typescript/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `src/adapters/openaicompat.ts` |
| Anthropic model | native | `src/adapters/anthropic.ts`; SSE streaming reassembly |
| Gemini model | native | `src/adapters/gemini.ts`; SSE streaming |
| MCP client | native | `src/adapters/mcp.ts`; stdio, plus `src/adapters/mcp-http.ts` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `src/adapters/harmovela.ts` |
| OpenTelemetry sink | native (transport seam) | `src/adapters/otel.ts`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native | `src/delegation.ts` `SubagentManager` |
| Retriever | native | `src/retriever.ts` `Document` and `Retriever` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples): runnable language-specific examples.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial): scenario-oriented tutorials.
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
