# PRAXO-CORE TypeScript

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `@axisvela/praxo-core`
- registry: [npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.6.0)
- source_version: `0.6.0`
- published_version: `0.6.0`
- install_published: `npm install @axisvela/praxo-core@0.6.0`
- install_source: `npm install ./language/typescript`
- source_tag: `typescript/v0.6.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/typescript/

## Capabilities and Status

- OpenAI-compatible model: native (`src/adapters/openaicompat.ts`)
- Anthropic model: native (`src/adapters/anthropic.ts`)
- Gemini model: native (`src/adapters/gemini.ts`)
- MCP client: native (`src/adapters/mcp.ts`; stdio, plus `src/adapters/mcp-http.ts` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`src/adapters/harmovela.ts`)
- OpenTelemetry sink: native (transport seam) (`src/adapters/otel.ts`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (`src/delegation.ts` `SubagentManager`)
- Retriever: native (`src/retriever.ts` `Document` and `Retriever`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples): runnable language-specific examples.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
