# PRAXO-CORE C++ Registry Introduction

**Status:** source-only. Source version `0.6.0`, source
tag `cpp/v0.6.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

C++20 implementation of the PRAXO-CORE agent contract. The normative contract is [`spec/`](../../spec/README.md); Go remains the reference implementation.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-cpp` |
| Registry | Source / CMake |
| Source version | `0.6.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `CMake source build (see README)` |
| Source tag | `cpp/v0.6.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/cpp/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native (transport seam) | `OpenAICompatible`; caller supplies HTTP transport |
| Anthropic model | native (transport seam) | `Anthropic`; caller supplies HTTP transport |
| Gemini model | native (transport seam) | `Gemini`; caller supplies HTTP transport |
| MCP client | native (transport seam) | `McpClient`; caller supplies `McpTransport` |
| Harmovela sink | native (transport seam) | `HarmovelaSink`; caller supplies HTTP transport |
| OpenTelemetry sink | not implemented |  |

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
