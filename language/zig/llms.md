# PRAXO-CORE Zig

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for Zig, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

This is a language-specific discovery entry, not a guarantee of indexing or adoption.

## Package

- package: `praxo-core-zig`
- registry: Source
- source_version: `0.9.0`
- published_version: not published
- install_published: not published
- install_source: `Source build (see README)`
- source_tag: `zig/v0.9.0`
- tier: Core
- contract: `SPEC_VERSION` `0.2.0`
- documentation: https://axisvela.github.io/praxo-core/languages/zig/

## Start

- README: `README.md`
- Registry introduction: `REGISTRY.md`
- Markdown entry: `llms.md`
- Compact entry: `llms.txt`
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/zig/examples): runnable language-specific examples; see each README for prerequisites and verification.

### Scenario tutorials

- [drone-fleet-plan](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/drone-fleet-plan): A bounded first slice of TL-01, not an airspace or flight-control system. It reads fixed drone waypoint state, drafts a review-only waypoint plan and flags a conflict zone for application-owned review. No flight, avoidance or geofence command.
- [gateway-health](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health): A scoped edge tutorial over the native MIT Zig Core. It reads one fixed `gateway-100` health snapshot through an application-owned `GatewayAdapter` function table and drafts an operator review action. The adapter is an in-process fixture. This tutorial does not implement MQTT, OPC UA, a socket, a real device SDK, a live model or a device write.

### Reference applications

No accepted end-to-end reference application is recorded for this language yet.

Application source is not end-to-end portfolio acceptance; read each README for scope and evidence.

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the [reference application portfolio](https://axisvela.github.io/praxo-core/project/planning/roadmap/#reference-application-portfolio).
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and reference-application paths.
- Coding-agent contract: ../../docs/getting-started/coding-agents.md

## Capabilities and Status

- OpenAI-compatible model: native (`openaicompat.Adapter` with `std.http`; SSE streaming reassembly)
- Anthropic model: native (`anthropic.Adapter`; injectable transport; `generateStream` reassembles Anthropic SSE)
- Gemini model: native (`gemini.Adapter`; injectable transport; `generateStream` reassembles Gemini SSE)
- MCP client: native (`mcp.Client`; stdio and curl-backed `HttpTransport` for Streamable HTTP 2025-03-26)
- Harmovela sink: native (`harmovela`)
- OpenTelemetry sink: native (transport seam) (`otel.Sink`; caller supplies OTLP/HTTP transport)
- Subagent delegation: native (synchronous seam) (`delegation.subagentRun`; no asynchronous manager)
- Retriever: native (`retriever.Document`, `retriever.Retriever`, `retriever.retrieveDocuments`)

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
