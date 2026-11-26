# PRAXO-CORE COBOL Registry Introduction

**Status:** source-only. Source version `0.9.0`, source
tag `cobol/v0.9.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native GnuCOBOL Core: an in-process agent loop with tools, policy, middleware, events, checkpoints, and human-in-the-loop decisions, implemented in COBOL rather than bridged to another Core.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-cobol` |
| Registry | Source |
| Source version | `0.9.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `Source build (see README)` |
| Source tag | `cobol/v0.9.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/cobol/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native (transport seam) | `praxo-openai`; caller supplies a transport program and an optional delta program; SSE streaming reassembles content, tool calls, usage, and finish reason; the model callback lacks tool specs/history |
| Anthropic model | native (transport seam) | `praxo-anthropic`; caller supplies a transport program; maps system messages, tools, tool choice, text, tool use, and usage |
| Gemini model | native (transport seam) | `praxo-gemini`; caller supplies a transport program; maps system instructions, tools, tool choice, text, function calls, usage, and Gemini SSE streaming |
| MCP client | native (transport seam) | `praxo-mcp`; caller supplies a transport program |
| Harmovela sink | native (transport seam) | `praxo-harmovela`; caller supplies a transport program |
| OpenTelemetry sink | native (transport seam) | `praxo-otel`; caller supplies an OTLP/HTTP transport program |
| Subagent delegation | native (synchronous seam) | `praxo-delegation`; synchronous runner callback; no asynchronous manager |
| Retriever | native | `praxo-retriever`; callback seam over query and limit |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [batch-exception-review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review): This tutorial reuses the existing [`language/cobol/examples/batch-exception-review`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/batch-exception-rev...
  - [budget-review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/budget-review): Flags fixed budget variances and milestone mismatches. No audit conclusion or official determination.
  - [legacy-migration](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/legacy-migration): Inventories three fixed modules and reports activation and batch counts. No code conversion or production migration.
  - [medical-coding](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/medical-coding): Checks three fixed records for completeness and drafts review-only codes. No reimbursement optimization, billing submission or clinical decision.
- Reference applications: no accepted end-to-end application yet; candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

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

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
