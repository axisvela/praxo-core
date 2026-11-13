# PRAXO-CORE MATLAB Registry Introduction

**Status:** published; MATLAB runtime compatibility unverified. Source version `0.4.0`, source
tag `matlab/v0.4.0`. Published registry version: `0.3.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

> **MATLAB runtime compatibility is unverified.** Current execution evidence is > GNU Octave 11.3.0 only. No MATLAB release or Windows/macOS/Linux MATLAB support > matrix has been independently validated. File Exchange compatibility labels > are not test evidence; do not use them as a production support promise.

## Package

| Field | Value |
| --- | --- |
| Package | `PRAXO-CORE` |
| Registry | [MATLAB File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core) |
| Source version | `0.4.0` |
| Published registry version | `0.3.0` |
| Install (published) | `File Exchange entry 185166` |
| Install (source/release prepared) | `File Exchange entry 185166` |
| Source tag | `matlab/v0.4.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/matlab/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `praxo.openai_compatible` using `webwrite` |
| Anthropic model | native | `praxo.anthropic_compatible`; injectable transport |
| Gemini model | native | `praxo.gemini_compatible`; injectable transport |
| MCP client | native (transport seam) | `praxo.mcp_client`; caller supplies a function handle |
| Harmovela sink | native | `praxo.harmovela_sink` |
| OpenTelemetry sink | not implemented |  |
| Subagent delegation | not implemented |  |
| Retriever | not implemented |  |

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
