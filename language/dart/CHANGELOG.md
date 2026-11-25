# Changelog

## 0.8.0 - 2026-11-26

Source tag `dart/v0.8.0`.

- Minor release for AI-native reference applications, scenario tutorials, and the Go examples layout refresh.

## 0.6.2 - 2026-11-18

Source tag `dart/v0.7.0`.

Source tag `dart/v0.6.2`; pub.dev publication follows the release workflow.

### Added

- Representative-chain, advanced-delegation, and the expanded task-oriented
  example index, including MCP, OTel/Harmovela, and governance checks.
- Registry README links for the current example set.

### Compatibility

- No public API or wire change; `SPEC_VERSION` remains `0.2.0`.

## 0.7.0 - 2026-11-20

### Added

- Deterministic representative-chain example covering MCP, final-argument
  authorization, governed child delegation, OTel/Harmovela events, and an edited
  denial with zero effects.
- Advanced-delegation example plus six application-level governance checks.

## 0.6.1 - 2026-11-16

Source tag `dart/v0.6.1`.

### Added

- A minimal `example/` entry for pub.dev and a README index for the thirteen
  repository examples.
- GitHub Actions OIDC publishing configuration in the monorepo.

### Changed

- The published archive excludes the plural `language/go/examples/` directory; the README
  links the full examples from the repository.
- Corrected the published version reference to `0.4.0` while the source moves to
  `0.6.1`.

## 0.6.0 - 2026-11-15

Source tag `dart/v0.6.0`.

### Added

- HITL interrupt decisions via `AgentOptions.interruptOn`,
  `onInterruptDecision`, and `onInterrupt`, with approve, edit, reject, and
  respond actions, `tool.interrupt` events, and edit reauthorization.

## 0.5.0 - 2026-11-15

Source tag `dart/v0.5.0`.

### Added

- `AgentOptions.requirePolicy` rejects construction without a policy hook.
- `AgentOptions.requireToolScope` rejects construction with an empty
  `allowedTools` list.
- Both guards are opt-in and default to `false`.

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