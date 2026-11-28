# PRAXO-CORE PowerShell

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for PowerShell, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

This is a language-specific discovery entry, not a guarantee of indexing or adoption.

## Package

- package: `praxo-core-ps`
- registry: [PowerShell Gallery](https://www.powershellgallery.com/packages/praxo-core-ps/0.9.1)
- source_version: `0.9.1`
- published_version: `0.9.1`
- install_published: `Install-Module praxo-core-ps`
- install_source: `Install-Module praxo-core-ps`
- source_tag: `powershell/v0.9.1`
- tier: Core (.NET)
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/powershell/

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [finops-review](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/finops-review): A bounded cloud cost-review tutorial. It reads fixed resource costs, computes the highest-cost resource below a 5% utilization threshold, and drafts a review-only action. No cloud API is called and no resource is terminated.
- [windows-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics): A read-only Windows operations tutorial. PowerShell calls the shared C# Core through `praxo-core-ps`; the Agent has two fixed tools, `read_service` and `read_disk`. It produces a structured report and never executes a model-selected command, changes a service, deletes files, or performs a repair.

### Reference applications

No accepted end-to-end reference application is recorded for this language yet.

Application source is not end-to-end portfolio acceptance; read each README for scope and evidence.

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Capabilities and Status

- OpenAI-compatible model: inherited (Uses the C# Core)
- Anthropic model: inherited (Uses the C# Core)
- Gemini model: inherited (Uses the C# Core)
- MCP client: native (C# shared runtime) (`Connect-PraxoMcp`, `Get-PraxoMcpTools`, `Invoke-PraxoMcpTool`; wraps the C# MCP client and stdio/Streamable HTTP transports)
- Harmovela sink: inherited (Uses the C# Core)
- OpenTelemetry sink: inherited (Uses the C# Core)
- Subagent delegation: native (synchronous wrapper) (Reuses C# request/result/task types; no asynchronous manager)
- Retriever: inherited (wrapper) (Wraps C# `Retriever`)

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
- Reference application sources are not end-to-end portfolio acceptance.

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
