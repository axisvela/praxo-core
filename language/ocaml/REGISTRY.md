# PRAXO-CORE OCaml Registry Introduction

**Status:** pending registry merge. Source version `0.5.0`, source
tag `ocaml/v0.5.0`. Published registry version: `0.3.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native OCaml Core with source tag `ocaml/v0.5.0`. It passes all eleven vector groups on OCaml 4.14.2 bytecode and includes the native agent loop, memory store, checkpoint allowlist, lexical path policy, context compaction, event sinks, middleware helpers, tool selection, and non-streaming OpenAI-compatible, Anthropic, and Gemini model adapters. It does not call Go or another language Core; there is no process bridge or plugin host.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [opam (pending)](https://github.com/axisvela/praxo-core-ocaml) |
| Source version | `0.5.0` |
| Published registry version | `0.3.0` |
| Install (published) | `opam install praxo-core` |
| Install (source/release prepared) | `opam install praxo-core` |
| Source tag | `ocaml/v0.5.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/ocaml/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native (transport seam) | Caller supplies `transport`; no bundled HTTP client |
| Anthropic model | native (transport seam) | `anthropic_model`; caller supplies transport |
| Gemini model | native (transport seam) | `gemini_model`; caller supplies transport |
| MCP client | native (transport seam) | `mcp_client`; caller supplies transport |
| Harmovela sink | native (transport seam) | `harmovela_sink`; caller supplies transport |
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
