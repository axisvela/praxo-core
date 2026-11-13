# PRAXO-CORE Zig Registry Introduction

**Status:** source-only. Source version `0.4.0`, source
tag `zig/v0.4.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

Zig 0.17 implementation of the PRAXO-CORE agent contract. The normative contract is [`spec/`](../../spec/README.md); Go remains the reference implementation.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-zig` |
| Registry | Source |
| Source version | `0.4.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `Source build (see README)` |
| Source tag | `zig/v0.4.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/zig/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `openaicompat.Adapter` with `std.http` |
| Anthropic model | native | `anthropic.Adapter`; injectable transport |
| Gemini model | native | `gemini.Adapter`; injectable transport |
| MCP client | native | `mcp.Client`; stdio and curl-backed `HttpTransport` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `harmovela` |
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
