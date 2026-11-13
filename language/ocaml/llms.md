# PRAXO-CORE OCaml

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core`
- registry: [opam (pending)](https://github.com/axisvela/praxo-core-ocaml)
- source_version: `0.6.0`
- published_version: `0.3.0`
- install_published: `opam install praxo-core`
- install_source: `opam install praxo-core`
- source_tag: `ocaml/v0.6.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/ocaml/

## Capabilities and Status

- OpenAI-compatible model: native (transport seam) (Caller supplies `transport`; no bundled HTTP client)
- Anthropic model: native (transport seam) (`anthropic_model`; caller supplies transport)
- Gemini model: native (transport seam) (`gemini_model`; caller supplies transport)
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
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
