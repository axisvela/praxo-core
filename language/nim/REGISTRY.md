# PRAXO-CORE Nim Registry Introduction

**Status:** split repository; registry crawler pending. Source version `0.4.0`, source
tag `nim/v0.4.0`. Published registry version: `0.1.1`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native Nim Core with source tag `nim/v0.4.0`. It passes all eleven shared vector groups with `Nim 2.2.12` and includes the native agent loop, context compaction, memory store, path policy, checkpoint allowlist, tool-call parsing, and opt-in agent tool selection, PII redaction, structured output, and call limits. Vector coverage does not establish full Core parity or production readiness.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo_core` |
| Registry | [Nimble/nim-lang packages](https://github.com/axisvela/praxo-core-nim) |
| Source version | `0.4.0` |
| Published registry version | `0.1.1` |
| Install (published) | `nimble install praxo_core` |
| Install (source/release prepared) | `nimble install praxo_core` |
| Source tag | `nim/v0.4.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/nim/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `praxo/adapters/openai_compatible` |
| Anthropic model | native | `newAnthropicCompatible`; injectable transport |
| Gemini model | native | `newGeminiCompatible`; injectable transport |
| MCP client | native (transport seam) | `praxo/adapters/mcp`; caller supplies transport |
| Harmovela sink | native | `newHarmovelaSink` |
| OpenTelemetry sink | native (transport seam) | `newOtelSink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `subagentRun`; no asynchronous manager |
| Retriever | native | `Document`, `Retriever`, `FuncRetriever`, `retrieveDocuments` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/nim/examples): runnable language-specific examples.
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
