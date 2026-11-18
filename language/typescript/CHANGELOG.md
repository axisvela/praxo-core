# TypeScript Core Release Notes

## 0.8.1 - 2026-11-18

Source tag `typescript/v0.8.1`; npm `0.8.1` is staged for maintainer approval.
Direct publish was denied by npm OIDC permissions, so `0.8.0` remains `latest`.

### Added

- Representative-chain, advanced-delegation, and the expanded task-oriented
  example index, including MCP, OTel/Harmovela, and governance checks.
- Registry README links for the current example set.

### Compatibility

- No public API or wire change; `SPEC_VERSION` remains `0.2.0`.


## 0.8.0 - 2026-11-15

Source tag `typescript/v0.8.0`.

### Added

- Authenticated HTTP service example with local HMAC or OIDC/JWKS bearer
  identities, tenant policy, an external policy decision endpoint, and
  file-backed checkpoints.

## 0.7.1 - 2026-11-15

### Changed

- Expanded the registry README with a Get started section and a task-oriented example index.

## 0.7.0 - 2026-11-14

Source tag `typescript/v0.7.0`; npm publication is pending.

### Added

- `AgentOptions.requirePolicy` rejects construction without a policy hook.
- `AgentOptions.requireToolScope` rejects construction with an empty
  `allowedTools` list.
- Both guards are opt-in and default to `false`.

## 0.6.0 - 2026-11-14

Source tag `typescript/v0.6.0`. npm publishes `@axisvela/praxo-core@0.6.0` from
that tag.

### Added

- OpenTelemetry event sink (`src/adapters/otel.ts`) over a caller-supplied
  OTLP/HTTP transport, with default event-data exclusion and an explicit
  data-key allowlist.
- Local subagent delegation (`src/delegation.ts`) with
  launch/check/wait/update/cancel and terminal states.
- Retriever seam (`src/retriever.ts` `Document`, `Retriever`, `FuncRetriever`).

### Fixed

- The OpenAI-compatible adapter now emits `tool_calls` and `tool_call_id`
  instead of the core wire names, so tool-result follow-ups work with strict
  endpoints such as DeepSeek.

## 0.5.0 - 2026-11-12

Source tag `typescript/v0.5.0`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.
- Native Anthropic Messages and Gemini generateContent model adapters.
- OpenAI-compatible provider presets for OpenAI, DeepSeek, Kimi/Moonshot,
  OpenRouter, Groq, and Together.

## 0.3.0 - 2026-11-10

Source tag `typescript/v0.3.0`. npm publishes `@axisvela/praxo-core@0.3.0` as
`latest`.

### Added

- Harmovela HTTP event sink in `src/adapters/harmovela.ts`.
- stdio MCP client in `src/adapters/mcp.ts` with fake-server tests.
- Adapter sources remain under `src/adapters/`.

### Compatibility

- Additive; the `0.2.2` public API remains available.

## 0.2.2 - 2026-11-08

Source tag `typescript/v0.2.2`. The tag workflow stages the npm package.

### Changed

- Registry README links now use absolute GitHub URLs so npm renders working
  `REGISTRY.md`, `llms.txt`, and `llms.md` links.

### Compatibility

- No runtime or public API changes.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.1 - 2026-11-08

Source tag `typescript/v0.2.1`. The tag workflow stages the npm package.

### Changed

- Package metadata and README now describe the published consumer starter,
  governed negative checks, and coding-agent integration guidance.

### Compatibility

- No runtime or public API changes.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-02

Source tag `typescript/v0.2.0`. The tag workflow stages the npm package.

### Added

- Human-in-the-loop interrupt decisions through `interruptOn`,
  `onInterruptDecision`, and `onInterrupt`.
- `Interrupt` and `InterruptDecision` with approve/edit/reject/respond actions.
  Interrupted calls emit `tool.interrupt` and edited arguments are reauthorized.

### Compatibility

- New options are optional and default to disabled.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
