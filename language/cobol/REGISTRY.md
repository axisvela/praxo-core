# PRAXO-CORE COBOL Registry Introduction

**Status:** source-only. Source version `0.4.0`, source
tag `cobol/v0.4.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

A native GnuCOBOL implementation, not a bridge to another Core. All 63 normative vectors across the eleven groups pass, together with native agent, JSON, contract-boundary, behavior, tooling, and API declaration checks. The `cobol-conformance` remote job checks the declared scope. `cobol/v0.4.0` is the source tag; version `0.4.0` adds middleware, lifecycle, cancellation, streaming, SSE, and batch tool dispatch, and current source adds human-in-the-loop interrupt decisions.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-cobol` |
| Registry | Source |
| Source version | `0.4.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `Source build (see README)` |
| Source tag | `cobol/v0.4.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/cobol/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | not implemented | No HTTP transport; model callback lacks tool specs/history |
| Anthropic model | not implemented |  |
| Gemini model | not implemented |  |
| MCP client | not implemented |  |
| Harmovela sink | not implemented | No HTTP transport; no event sink integration |

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
