# PRAXO-CORE C

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core-c`
- registry: Source / CMake
- source_version: `0.13.0`
- published_version: not published
- install_published: not published
- install_source: `CMake source build (see README)`
- source_tag: `c/v0.13.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/c/

## Capabilities and Status

- OpenAI-compatible model: native (transport seam) (`PxOpenAICompatible`; caller supplies HTTP transport; `px_openai_generate_stream` reassembles SSE content, tool calls, usage, and finish reason)
- Anthropic model: native (transport seam) (`PxAnthropic`; caller supplies HTTP transport; `px_anthropic_generate_stream` reassembles Anthropic SSE)
- Gemini model: native (transport seam) (`PxGemini`; caller supplies HTTP transport; `px_gemini_generate_stream` reassembles Gemini SSE)
- MCP client: native (transport seam) (`PxMcpClient`; caller supplies `PxMcpTransport`)
- Harmovela sink: native (transport seam) (`praxo_harmovela`; caller supplies HTTP transport)
- OpenTelemetry sink: native (transport seam) (`PxOtelSink`; caller supplies `PxOtelTransport`)
- Subagent delegation: native (synchronous seam) (`px_subagent_run`; no asynchronous manager)
- Retriever: native (`PxDocument`, `PxRetriever`, `px_retrieve`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/c/examples): runnable language-specific examples.
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
