# PRAXO-CORE GNU Octave Registry Introduction

**Status:** release tarball published; package index PR pending. Source version `0.5.0`, source
tag `octave/v0.5.0`. Published registry version: `0.2.1`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

Native Octave Core for the PRAXO-CORE agent framework. This is the independent Octave package root and source tag `octave/v0.5.0`; it shares the implementation in `language/matlab-octave-core/+praxo` with the MATLAB package. It passes all eleven shared vector groups under GNU Octave 11.3.0 and includes the native agent loop, memory store, checkpoint allowlist, lexical path policy, context compaction, event sinks, middleware helpers, tool selection, an OpenTelemetry transport-seam sink, a retriever seam, and synchronous subagent delegation. It does not delegate behavior to Go or another language Core.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [Octave Packages](https://github.com/axisvela/praxo-core/releases/download/octave/v0.2.1/praxo-core-0.2.1.tar.gz) |
| Source version | `0.5.0` |
| Published registry version | `0.2.1` |
| Install (published) | `pkg install -forge praxo-core` |
| Install (source/release prepared) | `pkg install -forge praxo-core` |
| Source tag | `octave/v0.5.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/octave/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | Shared `praxo.openai_compatible` implementation |
| Anthropic model | native | Shared `praxo.anthropic_compatible` |
| Gemini model | native | Shared `praxo.gemini_compatible` |
| MCP client | native (transport seam) | Shared `praxo.mcp_client` implementation |
| Harmovela sink | native | Shared `praxo.harmovela_sink` |
| OpenTelemetry sink | native (transport seam) | Shared `praxo.otel_sink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | Shared `praxo.subagent_run`; no asynchronous manager |
| Retriever | native | Shared `praxo.document` and `praxo.retrieve_documents` |

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
