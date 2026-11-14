# PRAXO-CORE Fortran Registry Introduction

**Status:** source-only. Source version `0.9.0`, source
tag `fortran/v0.9.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

A native Fortran 2008 agent implementation with source tag `fortran/v0.9.0`. Version `0.6.0` adds cancellation, stream callbacks, a native SSE parser, and caller-provided batch tool dispatch. Version `0.4.0` replaced the bounded ASCII matcher with upstream RE2 through a small C ABI library. The agent loop, JSON, policy, middleware, and human-in-the-loop interrupt decisions remain Fortran, not a bridge to another agent runtime. All 63 normative vectors across eleven groups and native regressions pass locally. Source tags do not imply package-registry publication.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-fortran` |
| Registry | Source / CMake |
| Source version | `0.9.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `Source build (see README)` |
| Source tag | `fortran/v0.9.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/fortran/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native (transport seam) | `openai_compatible`; caller supplies HTTP transport |
| Anthropic model | native (transport seam) | `anthropic_compatible`; caller supplies HTTP transport |
| Gemini model | native (transport seam) | `gemini_compatible`; caller supplies HTTP transport |
| MCP client | native (transport seam) | `mcp_client`; caller supplies transport |
| Harmovela sink | native (transport seam) | `harmovela`; caller supplies HTTP transport |
| OpenTelemetry sink | native (transport seam) | `otel_sink`; caller supplies transport |
| Subagent delegation | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Retriever | native | `document`, `retriever`, `retrieve_documents` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples): runnable language-specific examples.
- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
