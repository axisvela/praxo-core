# PRAXO-CORE Rust Registry Introduction

**Status:** published. Source version `0.11.1`, source
tag `rust/v0.11.1`. Published registry version: `0.11.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This crate is its native Rust Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, and plugin manifest parsing. It runs in-process and does not require a hosted service.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [crates.io](https://crates.io/crates/praxo-core/0.11.0) |
| Source version | `0.11.1` |
| Published registry version | `0.11.0` |
| Install (published) | `cargo add praxo-core@0.11.1` |
| Install (source/release prepared) | `cargo add --path language/rust` |
| Source tag | `rust/v0.11.1` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/rust/ |

## Capabilities and Status

| Adapter | Status | Detail |
| --- | --- | --- |
| OpenAI-compatible model | native | `openai_compat::OpenAICompatible` behind optional `http-ureq`; `parse_stream` always available |
| Anthropic model | native (transport seam) | `adapters::anthropic`; caller supplies transport; `StreamingModel` via `send_stream` |
| Gemini model | native (transport seam) | `adapters::gemini`; caller supplies transport; `StreamingModel` via `send_stream` |
| MCP client | native | `mcp::McpClient`; stdio, plus `McpClient::connect_http` over a caller-supplied `McpHttpTransport` seam for Streamable HTTP 2025-03-26 |
| Harmovela sink | native | `harmovela::Sink` |
| OpenTelemetry sink | native (transport seam) | `adapters::otel::Sink`; caller supplies OTLP/HTTP transport |
| Subagent delegation | native | `delegation::SubagentManager` |
| Retriever | native | `retriever::Document` and `Retriever` |

## Coding-agent entry

- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples): runnable language-specific examples.
- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Scenario tutorials:
  - [biodiversity-alerts](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/biodiversity-alerts): Classify fixed labeled observations and draft a ranger review. No production write or external system access.
  - [bug-repair](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/bug-repair): Reproduces a fixed bug, drafts a patch and reruns a fixture test. No PR creation or repository write.
  - [code-review](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/code-review): Reviews a fixed diff and dependency manifest, cites findings and uncertainty and drafts comments. No comments are posted.
  - [cold-chain](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/cold-chain): A bounded first slice of TL-04, not a refrigeration-control or clinical-cargo system. It computes fixed temperature excursions and drafts a review-only transfer review. No refri...
  - [construction-safety](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/construction-safety): A bounded first slice of BE-01, not a certified safety inspection. It reads fixed inspection labels for one site, drafts a review-only remediation checklist and records zero cer...
  - [copyright-evidence](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/copyright-evidence): Compare fixed authorized assets and draft an evidence packet. No production write or external system access.
  - [dlp-redaction](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/dlp-redaction): Inspect a fixed export and draft a review-only redaction. No production write or external system access.
  - [drone-fleet-plan](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/drone-fleet-plan): Simulate fixed waypoints and conflict checks, then draft a plan. No production write or external system access.
  - [fleet-map](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/fleet-map): Replay fixed road-topology changes and draft a reviewed map patch. No production write or external system access.
  - [household-robot](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/household-robot): A bounded first slice of PE-04, not a robot controller. It observes fixed robot state with freshness, drafts a bounded review-only action that requires cancel confirmation, and...
  - [iot-gateway](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway): A scoped edge tutorial over the published MIT `praxo-core` Rust crate. It reads one fixed gateway snapshot through an application-owned `GatewayAdapter` trait, asks a determinis...
  - [lab-loop](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/lab-loop): A bounded first slice of SC-03, not an autonomous laboratory. It replays a fixed parameter/result loop with deterministic limits and drafts review-only next parameters. No labor...
  - [leak-localization](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/leak-localization): A bounded first slice of CT-02, not a leak-detection or dispatch system. It ranks fixed synthetic pressure anomalies and drafts a review-only inspection list. No valve isolation...
  - [livestock-monitor](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/livestock-monitor): A bounded first slice of AE-01, not a veterinary or feeding-control system. It summarizes fixed animal observations and drafts a review-only veterinary request. No diagnosis, is...
  - [mining-slope](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/mining-slope): A bounded first slice of BE-03, not a collapse-prediction or dispatch system. It reads fixed slope displacement indicators and drafts a review-only alert. No collapse prediction...
  - [pentest-lab-review](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/pentest-lab-review): Inventory one allowlisted loopback lab and draft a review-only report. No production write or external system access.
  - [privacy-agent](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/privacy-agent): Classify fixed messages and draft a review-only deletion request. No production write or external system access.
  - [quant-risk](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/quant-risk): Replays fixed prices, enforces a deterministic exposure limit and drafts a review-only order. No trade or latency claim.
  - [supply-chain-review](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/supply-chain-review): Compare fixed manifests and draft a reviewed version pin. No production write or external system access.
  - [threat-hunting](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/threat-hunting): Search fixed logs and draft a cited synthetic TTP timeline. No production write or external system access.
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
