# PRAXO-CORE TypeScript

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `@axisvela/praxo-core`
- registry: [npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.9.0)
- source_version: `0.10.0`
- published_version: `0.9.0`
- install_published: `npm install @axisvela/praxo-core@0.9.0`
- install_source: `npm install ./language/typescript`
- source_tag: `typescript/v0.10.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/typescript/

## Capabilities and Status

- OpenAI-compatible model: native (`src/adapters/openaicompat.ts`)
- Anthropic model: native (`src/adapters/anthropic.ts`; SSE streaming reassembly)
- Gemini model: native (`src/adapters/gemini.ts`; SSE streaming)
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
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial): scenario-oriented tutorials.
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
