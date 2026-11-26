# PRAXO-CORE OCaml

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core`
- registry: [opam (pending)](https://github.com/axisvela/praxo-core-ocaml)
- source_version: `0.10.0`
- published_version: `0.3.0`
- install_published: `opam install praxo-core`
- install_source: `opam install praxo-core`
- source_tag: `ocaml/v0.10.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/ocaml/

## Capabilities and Status

- OpenAI-compatible model: native (transport seam) (Caller supplies `transport`; no bundled HTTP client; SSE streaming reassembly)
- Anthropic model: native (transport seam) (`anthropic_model`; caller supplies transport; `anthropic_generate_stream` reassembles Anthropic SSE)
- Gemini model: native (transport seam) (`gemini_model`; caller supplies transport; `gemini_generate_stream` reassembles Gemini SSE)
- MCP client: native (transport seam) (`mcp_client`; caller supplies transport)
- Harmovela sink: native (transport seam) (`harmovela_sink`; caller supplies transport)
- OpenTelemetry sink: native (transport seam) (`otel_sink_new` and `otel_emit`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`subagent_run`; no asynchronous manager)
- Retriever: native (`document` and `retrieve_documents`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
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
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

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

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
