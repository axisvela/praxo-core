# PRAXO-CORE Java Registry Introduction

**Status:** published. Source version `0.7.1`, source
tag `java/v0.7.1`. Published registry version: `0.6.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

Java implementation of the PRAXO-CORE contract. The normative contract is [`spec/`](../../spec/README.md); Go remains the reference implementation.

## Package

| Field | Value |
| --- | --- |
| Package | `com.axisvela:praxo-core` |
| Registry | [Maven Central](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.6.0/) |
| Source version | `0.7.1` |
| Published registry version | `0.6.0` |
| Install (published) | `Maven: com.axisvela:praxo-core:0.6.0` |
| Install (source/release prepared) | `Maven: com.axisvela:praxo-core:0.7.1` |
| Source tag | `java/v0.7.1` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/java/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `adapters.OpenAICompatibleModel` |
| Anthropic model | native | `adapters.AnthropicModel` |
| Gemini model | native | `adapters.GeminiModel` |
| MCP client | native | `adapters.McpClient`; stdio, plus `McpStreamableHttpTransport` for Streamable HTTP 2025-03-26 (local runtime verification pending) |
| Harmovela sink | native | `adapters.HarmovelaSink` |

## Coding-agent entry

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
