# PRAXO-CORE Swift Registry Introduction

**Status:** package list merged. Source version `0.4.0`, source
tag `swift/v0.4.0`. Published registry version: `0.2.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

Swift implementation of the PRAXO-CORE contract.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-swift` |
| Registry | [Swift Package Index](https://swiftpackageindex.com/axisvela/praxo-core-swift) |
| Source version | `0.4.0` |
| Published registry version | `0.2.0` |
| Install (published) | `.package(url: "https://github.com/axisvela/praxo-core-swift.git", from: "0.2.0")` |
| Install (source/release prepared) | `.package(url: "https://github.com/axisvela/praxo-core-swift.git", from: "0.4.0")` |
| Source tag | `swift/v0.4.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/swift/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `OpenAICompatibleModel` with URLSession transport |
| Anthropic model | native | `AnthropicModel` with injectable transport |
| Gemini model | native | `GeminiModel` with injectable transport |
| MCP client | native | `McpClient`, `StdioMcpTransport`, `HttpMcpTransport`; typechecked locally, full build blocked |
| Harmovela sink | native | `HarmovelaSink` with URLSession transport |

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
