# PRAXO-CORE Erlang Registry Introduction

**Status:** published. Source version `0.10.0`, source
tag `erlang/v0.10.0`. Published registry version: `0.9.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native Erlang Core with source tag `erlang/v0.10.0`. It passes all eleven shared vector groups on Erlang/OTP 29 and includes the native agent loop, memory store, checkpoint allowlist, lexical path policy, context compaction, event sinks, middleware helpers, tool selection, and human-in-the-loop interrupt decisions. It does not call Go or another Core.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo_core_erlang` |
| Registry | [Hex](https://hex.pm/packages/praxo_core_erlang/0.9.0) |
| Source version | `0.10.0` |
| Published registry version | `0.9.0` |
| Install (published) | `{praxo_core, "0.9.0", {pkg, praxo_core_erlang}}` |
| Install (source/release prepared) | `{praxo_core, {path, "language/erlang"}}` |
| Source tag | `erlang/v0.10.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/erlang/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `praxo_openai_compatible`; `streaming_model/1` and `generate_stream/3` reassemble SSE content, tool calls, usage, and finish reason |
| Anthropic model | native | `praxo_anthropic`; `streaming_model/1` reassembles Anthropic SSE |
| Gemini model | native | `praxo_gemini`; `streaming_model/1` reassembles Gemini SSE |
| MCP client | native | `praxo_mcp`; stdio, plus `praxo_mcp_http:transport/2` for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `praxo_harmovela` |
| OpenTelemetry sink | native (transport seam) | `praxo_otel`; caller supplies transport |
| Subagent delegation | native (synchronous seam) | `praxo_delegation:subagent_run/2`; no asynchronous manager |
| Retriever | native | `praxo_retriever:document`, `func_retriever`, `retrieve/3` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples): runnable language-specific examples.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/erlang/Tutorial): scenario-oriented tutorials.
- [Reference applications](https://github.com/axisvela/praxo-core/tree/main/language/erlang/application): AI-native reference applications.
- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- GitHub Issues: <https://github.com/axisvela/praxo-core/issues>
- Documentation: <https://axisvela.github.io/praxo-core/>
- Architect: <https://axisvela.architect.pub>

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
