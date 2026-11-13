# Changelog

## 0.4.0 - 2026-11-13

Source tag `dart/v0.4.0`.

### Added

- OpenTelemetry OTLP/HTTP sink over an injected `OtelTransport`.
- Retriever document/query/limit seam with `FuncRetriever`.
- Synchronous subagent delegation seam with `SubagentManager`.
- MCP Streamable HTTP (2025-03-26) transport and client support.

## 0.3.0 - 2026-11-12

Source tag `dart/v0.3.0`.

- Add native Anthropic Messages and Gemini generateContent adapters with sync
  and async transports.
- Add a stdio MCP client with pagination, tool calls, timeouts, and
  cancellation notifications.

## 0.1.1

- Publish the package to pub.dev as `praxo_core` with publisher metadata,
  `lib/praxo_core.dart`, and the conventional `test/` layout.

## 0.1.0

- Initial Dart Core package for the PRAXO-CORE agent framework.
- Implements all eleven conformance vector groups.
- Includes the agent loop, tools, policy, events, memory, checkpoints, context,
  middleware, JSON Schema, and plugin manifest parsing.
