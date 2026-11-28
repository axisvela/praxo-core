# PRAXO-CORE OCaml Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for OCaml, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** not published; replacement submission pending. Source version `0.11.1`, source
tag `ocaml/v0.11.1`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [opam (pending)](https://github.com/axisvela/praxo-core-ocaml) |
| Source version | `0.11.1` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `Source checkout: language/ocaml (see README build instructions)` |
| Source tag | `ocaml/v0.11.1` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/ocaml/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/ocaml/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [architecture-graph](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/architecture-graph): A bounded first slice of OG-01, not an enterprise-architecture control plane. It compares a fixed application/API graph with stated standards and drafts review-only change findings. No production scanning, automatic blocking or live model.
- [bom-review](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/bom-review): A bounded first slice of [IN-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not CAD/BIM parsing or engineering certification. It reads a fixed parsed drawing, reports one clearance conflict, and drafts a review-only BOM. No CAD access or live model.
- [code-review](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/code-review): A bounded first slice of [SE-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a full security or license audit. It reads a fixed diff and dependency manifest, flags a high-severity unsafe-shell rule and a missing test, and drafts a review-only comment set. This uses the source OCaml Core through the `ocaml` toplevel; no network, credentials or packages beyond OCaml are required.
- [contract-review](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/contract-review): A bounded first slice of [FC-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not legal advice or an e-signature system. It compares fixed contract clauses to a redline set and drafts review-only redlines. No document store or live model.
- [static-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/static-diagnostics): A bounded static-analysis review tutorial. It parses structured diagnostic lines, counts high/low rules and returns source locations. Core chooses a review level from the actual counts and drafts findings without editing source.

### Reference applications

No accepted end-to-end reference application is recorded for this language yet.

Application source is not end-to-end portfolio acceptance; read each README for scope and evidence.

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/planning/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

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

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
- Reference application sources are not end-to-end portfolio acceptance. See each
  README and the [verification evidence](https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/).

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
