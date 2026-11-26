# PRAXO-CORE OCaml Registry Introduction

**Status:** pending registry merge. Source version `0.10.0`, source
tag `ocaml/v0.10.0`. Published registry version: `0.3.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed AI agent framework. This package is its native OCaml Core with source tag `ocaml/v0.10.0`. It passes all eleven vector groups on OCaml 4.14.2 bytecode and includes the native agent loop, memory store, checkpoint allowlist, lexical path policy, context compaction, event sinks, middleware helpers, tool selection, streaming OpenAI-compatible and Anthropic, and\nGemini streaming model adapters. It does not call Go or another language Core; there is no process bridge or plugin host.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [opam (pending)](https://github.com/axisvela/praxo-core-ocaml) |
| Source version | `0.10.0` |
| Published registry version | `0.3.0` |
| Install (published) | `opam install praxo-core` |
| Install (source/release prepared) | `opam install praxo-core` |
| Source tag | `ocaml/v0.10.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/ocaml/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native (transport seam) | Caller supplies `transport`; no bundled HTTP client; SSE streaming reassembly |
| Anthropic model | native (transport seam) | `anthropic_model`; caller supplies transport; `anthropic_generate_stream` reassembles Anthropic SSE |
| Gemini model | native (transport seam) | `gemini_model`; caller supplies transport; `gemini_generate_stream` reassembles Gemini SSE |
| MCP client | native (transport seam) | `mcp_client`; caller supplies transport |
| Harmovela sink | native (transport seam) | `harmovela_sink`; caller supplies transport |
| OpenTelemetry sink | native (transport seam) | `otel_sink_new` and `otel_emit`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Retriever | native | `document` and `retrieve_documents` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [architecture-graph](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/architecture-graph): A bounded first slice of OG-01, not an enterprise-architecture control plane. It compares a fixed application/API graph with stated standards and drafts review-only change findi...
  - [bom-review](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/bom-review): A bounded first slice of [IN-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not CAD/BIM parsing or engineering certification. It reads a fixed pars...
  - [code-review](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/code-review): A bounded first slice of [SE-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a full security or license audit. It reads a fixed diff and depende...
  - [contract-review](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/contract-review): A bounded first slice of [FC-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not legal advice or an e-signature system. It compares fixed contract c...
  - [static-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/static-diagnostics): A bounded static-analysis review tutorial. It parses structured diagnostic lines, counts high/low rules and returns source locations. Core chooses a review level from the actual...
- Reference applications: no accepted end-to-end application yet; candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
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
