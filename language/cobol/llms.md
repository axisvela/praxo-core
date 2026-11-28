# PRAXO-CORE COBOL

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for COBOL, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

This is a language-specific discovery entry, not a guarantee of indexing or adoption.

## Package

- package: `praxo-core-cobol`
- registry: Source
- source_version: `0.9.0`
- published_version: not published
- install_published: not published
- install_source: `Source build (see README)`
- source_tag: `cobol/v0.9.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/cobol/

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [batch-exception-review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review): This tutorial reuses the existing [`language/cobol/examples/batch-exception-review`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/batch-exception-review) fixture. It does not create a second bank model or a second COBOL review worker.
- [budget-review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/budget-review): Flags fixed budget variances and milestone mismatches. No audit conclusion or official determination.
- [legacy-migration](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/legacy-migration): Inventories three fixed modules and reports activation and batch counts. No code conversion or production migration.
- [medical-coding](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/medical-coding): Checks three fixed records for completeness and drafts review-only codes. No reimbursement optimization, billing submission or clinical decision.

### Reference applications

- [application](https://github.com/axisvela/praxo-core/tree/main/language/cobol/application): A native GnuCOBOL batch reviewer where the agent drives the primary exception workflow: the driver reads a bounded exception file, the agent inspects each allowed record, writes a diagnosis and rationale, and drafts a review-only advisory. The batch never posts an adjustment and private records are denied before the read.

Application source is not end-to-end portfolio acceptance; read each README for scope and evidence.

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Capabilities and Status

- OpenAI-compatible model: native (transport seam) (`praxo-openai`; caller supplies a transport program and an optional delta program; SSE streaming reassembles content, tool calls, usage, and finish reason; the model callback lacks tool specs/history)
- Anthropic model: native (transport seam) (`praxo-anthropic`; caller supplies a transport program; maps system messages, tools, tool choice, text, tool use, and usage)
- Gemini model: native (transport seam) (`praxo-gemini`; caller supplies a transport program; maps system instructions, tools, tool choice, text, function calls, usage, and Gemini SSE streaming)
- MCP client: native (transport seam) (`praxo-mcp`; caller supplies a transport program)
- Harmovela sink: native (transport seam) (`praxo-harmovela`; caller supplies a transport program)
- OpenTelemetry sink: native (transport seam) (`praxo-otel`; caller supplies an OTLP/HTTP transport program)
- Subagent delegation: native (synchronous seam) (`praxo-delegation`; synchronous runner callback; no asynchronous manager)
- Retriever: native (`praxo-retriever`; callback seam over query and limit)

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
