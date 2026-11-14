# PRAXO-CORE COBOL Registry Introduction

**Status:** source-only. Source version `0.6.0`, source
tag `cobol/v0.6.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

A native GnuCOBOL implementation, not a bridge to another Core. All 63 normative vectors across the eleven groups pass, together with native agent, JSON, contract-boundary, behavior, tooling, and API declaration checks. The `cobol-conformance` remote job checks the declared scope. `cobol/v0.6.0` is the source tag. Version `0.6.0` adds Anthropic and Gemini transport-seam model adapters, an OTLP/HTTP OpenTelemetry sink, a retriever seam, and a synchronous delegation seam. Earlier source adds middleware, lifecycle, cancellation, streaming, SSE, batch tool dispatch, MCP, Harmovela, OpenAI-compatible adapters, and human-in-the-loop interrupt decisions.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-cobol` |
| Registry | Source |
| Source version | `0.6.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `Source build (see README)` |
| Source tag | `cobol/v0.6.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/cobol/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native (transport seam) | `praxo-openai`; caller supplies a transport program; the model callback lacks tool specs/history |
| Anthropic model | native (transport seam) | `praxo-anthropic`; caller supplies a transport program; maps system messages, tools, tool choice, text, tool use, and usage |
| Gemini model | native (transport seam) | `praxo-gemini`; caller supplies a transport program; maps system instructions, tools, tool choice, text, function calls, and usage |
| MCP client | native (transport seam) | `praxo-mcp`; caller supplies a transport program |
| Harmovela sink | native (transport seam) | `praxo-harmovela`; caller supplies a transport program |
| OpenTelemetry sink | native (transport seam) | `praxo-otel`; caller supplies an OTLP/HTTP transport program |
| Subagent delegation | native (synchronous seam) | `praxo-delegation`; synchronous runner callback; no asynchronous manager |
| Retriever | native | `praxo-retriever`; callback seam over query and limit |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples): runnable language-specific examples.
- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
