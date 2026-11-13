# PRAXO-CORE C

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core-c`
- registry: Source / CMake
- source_version: `0.8.0`
- published_version: not published
- install_published: not published
- install_source: `CMake source build (see README)`
- source_tag: `c/v0.8.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/c/

## Capabilities and Status

- OpenAI-compatible model: native (transport seam) (`PxOpenAICompatible`; caller supplies HTTP transport)
- Anthropic model: native (transport seam) (`PxAnthropic`; caller supplies HTTP transport)
- Gemini model: native (transport seam) (`PxGemini`; caller supplies HTTP transport)
- MCP client: native (transport seam) (`PxMcpClient`; caller supplies `PxMcpTransport`)
- Harmovela sink: native (transport seam) (`praxo_harmovela`; caller supplies HTTP transport)
- OpenTelemetry sink: not implemented

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
