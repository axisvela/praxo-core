# PRAXO-CORE PowerShell

> Embeddable, governed agent execution kernel. This file is the language-specific
> registry and coding-agent entry; it does not guarantee discovery, installation,
> or adoption.

## Package

- package: `praxo-core-ps`
- registry: [PowerShell Gallery](https://www.powershellgallery.com/packages/praxo-core-ps/0.5.3)
- source_version: `0.5.3`
- published_version: `0.5.3`
- install_published: `Install-Module praxo-core-ps`
- install_source: `Install-Module praxo-core-ps`
- source_tag: `powershell/v0.5.3`
- tier: Core (.NET)
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/powershell/

## Capabilities and Status

- OpenAI-compatible model: inherited (Uses the C# Core)
- Anthropic model: inherited (Uses the C# Core)
- Gemini model: inherited (Uses the C# Core)
- MCP client: native (C# shared runtime) (`Connect-PraxoMcp`, `Get-PraxoMcpTools`, `Invoke-PraxoMcpTool`; wraps the C# MCP client and stdio/Streamable HTTP transports)
- Harmovela sink: inherited (Uses the C# Core)
- OpenTelemetry sink: inherited (Uses the C# Core)
- Subagent delegation: native (synchronous wrapper) (Reuses C# request/result/task types; no asynchronous manager)
- Retriever: inherited (wrapper) (Wraps C# `Retriever`)

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples): runnable language-specific examples.
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
