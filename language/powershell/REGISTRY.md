# PRAXO-CORE PowerShell Registry Introduction

## Positioning

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for PowerShell, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

**Status:** published; shared C# runtime. Source version `0.9.1`, source
tag `powershell/v0.9.1`. Published registry version: `0.9.1`. Registry
pages are release snapshots; verify the published version before relying on a feature.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-ps` |
| Registry | [PowerShell Gallery](https://www.powershellgallery.com/packages/praxo-core-ps/0.9.1) |
| Source version | `0.9.1` |
| Published registry version | `0.9.1` |
| Install (published) | `Install-Module praxo-core-ps` |
| Install (source/release prepared) | `Install-Module praxo-core-ps` |
| Source tag | `powershell/v0.9.1` |
| Tier | Core (.NET) |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/powershell/ |

## Get Started

Follow the [language README](https://axisvela.github.io/praxo-core/languages/powershell/) for runtime prerequisites,
installation, a first run, and local verification. The package table distinguishes
published installation from source builds; a pending registry is not available.

## Examples, Tutorials, and Applications

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
- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | inherited | Uses the C# Core |
| Anthropic model | inherited | Uses the C# Core |
| Gemini model | inherited | Uses the C# Core |
| MCP client | native (C# shared runtime) | `Connect-PraxoMcp`, `Get-PraxoMcpTools`, `Invoke-PraxoMcpTool`; wraps the C# MCP client and stdio/Streamable HTTP transports |
| Harmovela sink | inherited | Uses the C# Core |
| OpenTelemetry sink | inherited | Uses the C# Core |
| Subagent delegation | native (synchronous wrapper) | Reuses C# request/result/task types; no asynchronous manager |
| Retriever | inherited (wrapper) | Wraps C# `Retriever` |

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
- Reference application sources are not end-to-end portfolio acceptance. See each
  README and the [verification evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/).

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
