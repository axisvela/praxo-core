# PRAXO-CORE V Registry Introduction

**Status:** split repository; VPM submission pending. Source version `0.3.0`, source
tag `v/v0.3.0`. Published registry version: `0.1.2`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

V is a native Core implementation with source tag `v/v0.3.0`. It passes all eleven shared vector groups with `V 0.5.2` and includes the native agent loop, context compaction, memory store, path policy, checkpoint allowlist, and tool-call parsing. Tool selection, PII redaction, structured output, and call limits are opt-in in the agent. Vector coverage does not establish full Core parity or production readiness.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [VPM (pending)](https://github.com/axisvela/praxo-core-v) |
| Source version | `0.3.0` |
| Published registry version | `0.1.2` |
| Install (published) | `v install praxo-core` |
| Install (source/release prepared) | `v install praxo-core` |
| Source tag | `v/v0.3.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/v/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `praxo.openaicompat`; verified with V 0.5.2 and `x.json2` |
| Anthropic model | native (transport seam) | `anthropic_compatible`; caller supplies `ProviderTransport` |
| Gemini model | native (transport seam) | `gemini_compatible`; caller supplies `ProviderTransport` |
| MCP client | native (transport seam) | `praxo.mcp`; caller supplies `McpTransport` |
| Harmovela sink | native | `harmovela_sink`; verified with V 0.5.2 and `x.json2` |
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
