# Changelog

All notable changes to PRAXO-CORE are documented here.

## [0.16.0] - 2026-10-18

### Added

- Fuzz seeds for the manifest, tool-call, JSON Schema, and path parsers.
- CI matrix (Linux/Windows/macOS), race, fuzz, staticcheck, and govulncheck
  jobs.
- `examples/integrator`: a self-contained external-integrator wiring example.

### Changed

- Canonical package paths are now `pkg/toolcall` (was `pkg/output`),
  `pkg/formatter` (was `pkg/format`), and `pkg/tool/jsonschema` (was
  `pkg/tool/schema`). The old paths remain as deprecated aliases through the
  `0.16` line and are removed in `1.0.0`; migration is tracked in
  `docs/07-api-freeze.md`.
- `toolcall.ToolCall` documents `Operation`, `Resource`, `Risk`, `Reason`, and
  `IdempotencyKey` as optional product governance metadata; the parser does not
  interpret or validate them.
- `pkg/httpclient` bounds response bodies by default (`DefaultMaxBodyBytes`,
  32 MiB), with `Config.MaxBodyBytes` and `ErrBodyTooLarge` for callers.

## [0.15.0] - 2026-10-18

### Added

- `pkg/plugin/host/process` and `pkg/plugin/host/wasm`: process and WASM
  plugin hosts with platform resource supervisors, wire envelopes, and
  conformance tests. PRAXOVELA re-exports them as thin aliases.
- `pkg/plugin/bridge`: generic `plugin.Host` adapters for `tool.Tool`,
  `model.Model`, `policy.Hook`, `memory.Store`, and `sandbox.Sandbox`, with an
  injectable codec and configurable contract methods.
- Process host `Config.TokenEnvVar` for products that need a non-default
  channel-token environment variable; the v1 default remains
  `PRAXOVELA_PLUGIN_TOKEN`.
- `pkg/plugin/tck`: contract-level conformance kit for lifecycle, guarded
  registry, and host framing, timeout, cancellation, capability denial, and
  the not-active gate. Trust, materialization, evidence, and rolling-update
  conformance stay in PRAXOVELA.
- `pkg/plugin` Manifest v1: strict parsing and validation for schema version,
  reverse-DNS identity, semver, contract kind, entrypoint, isolation, protocol,
  capabilities, permissions, limits, health, signature, and SBOM, with signed
  and explicit unsigned trust profiles.
- `pkg/policy`: deny-by-default path containment checker (`PathChecker`) with
  read/write/readwrite grants, symlink resolution, traversal and sibling-prefix
  rejection, and Windows case-insensitive comparison.
- `pkg/agent`: `ContextBudget` prompt compaction with keep-recent turns,
  tool-call/result pairing, a deterministic token estimate, an
  `OnCompaction` hook, and fail-closed `ErrContextBudget` when the system
  prompt alone cannot fit.

### Changed

- `wazero` and `golang.org/x/sys` are direct framework dependencies for the
  WASM host and platform supervisors.

## [0.14.0] - 2026-10-18

### Added

- `pkg/plugin`: contract kinds, host boundary, lifecycle FSM, guarded adapter
  registry, per-plugin scope, resource limits, and telemetry events.
  PRAXOVELA aliases it; materialization, update, evidence, and binding stay
  product-side.

## [0.13.0] - 2026-10-18

### Added

- `pkg/httpclient` shared retry-capable HTTP transport with auth, tracing,
  idempotency-aware retries, and response decoding. PRAXOVELA adapters alias it.

## [0.12.0] - 2026-10-18

### Added

- `agent.Middleware` with before/after run, model, and tool hooks. Middleware
  may rewrite requests or skip execution with a canned result. Named entries
  replace earlier entries in place.

## [0.11.0] - 2026-10-18

### Added

- `Profile` bundles reusable defaults; explicit `Options` values win.
- `ModelMiddleware` wraps model calls in order.

## [0.10.0] - 2026-10-18

### Added

- `SkillProvider` and `Agent.Skills` for on-demand knowledge injection.
- `model.ResponseFormat` and `Agent.ResponseFormat` for structured output.
- `Agent.InterruptOn`/`OnInterrupt` for human approval before tool calls.
- `RunContext`, `RunWithContext`, `WithRunContext`, and `RunContextFrom` for
  per-run values.
- `agent.SessionStore` as the portable session persistence contract.

## [0.9.0] - 2026-10-18

### Added

- `New(Options)` constructor bundling model, prompt, tools, memory, policy,
  budgets, retry, hooks, and streaming.
- `Agent.SystemPrompt` is prepended as a system message.

## [0.8.0] - 2026-10-18

### Added

- `Agent.ToolChoice` and `Agent.AllowedTools` for tool-choice control and
  allowlisting (advertised and enforced).
- `Agent.MaxTokens` token budget with `ErrMaxTokens`.
- `Agent.Recall`/`RecallLimit` to inject matching memory records, plus
  `Hooks.OnMemoryRead` and `Hooks.OnMemoryWrite`.

## [0.7.0] - 2026-10-18

### Added

- `Agent.MaxParallelTools` runs tool calls from one model response
  concurrently while preserving message order.
- Tool panics are converted into errors instead of crashing the process.

## [0.6.0] - 2026-10-18

### Added

- `model.StreamingModel` for callback-based text streaming; set
  `Agent.OnDelta` to receive fragments.
- `Agent.Retry` (`RetryPolicy`) with attempt budget, backoff, and an optional
  retry predicate.
- `Agent.Hooks` lifecycle callbacks for run, step, model, tool, completion, and
  failure events.

### Fixed

- `Agent.Run` no longer mutates `MaxSteps` when it applies the default, making
  a shared agent safe for concurrent runs.

## [0.5.0] - 2026-10-18

### Added

- Extracted durable checkpoint snapshot types and the `Store` contract into
  `pkg/checkpoint`; PRAXOVELA keeps only the effect-ledger cursor builder.

## [0.4.0] - 2026-10-18

### Added

- Extracted the agent lifecycle `Status` state machine and tenant default into
  `pkg/agent`; PRAXOVELA now aliases the framework status contract.

## [0.3.0] - 2026-10-18

### Added

- Extracted PRAXOVELA's code formatter registry into `pkg/format`; PRAXOVELA
  now aliases the framework package.
- Added tool specs, middleware, and ordered wrapping.
- Added multi-sink and filter event sinks.
- Added an in-memory memory store and context assembler.
- Added the chat `Provider`/`ModelRouter` contract and `EchoProvider` from
  PRAXOVELA; PRAXOVELA's model contract package now aliases it.
- Added adapter bridges: `ChatModel`, tool `Gateway`, remote memory `Backend`,
  event `Publisher`, `policy.FuncHook`, and `sandbox.FuncSandbox`.

## [0.2.0] - 2026-10-18

### Added

- Extracted the scheduler engine from PRAXOVELA into `pkg/scheduler` with
  provenance recorded. PRAXOVELA now imports the framework scheduler and keeps
  only a thin product alias.
- Extracted tool-call parsing into `pkg/output` and JSON Schema validation into
  `pkg/tool/schema`. PRAXOVELA now aliases both framework packages.
- Added `pkg/flow` Runnable/Chain/Parallel composition.
- Added `pkg/prompt` template and chat-template interpolation.
- Added `pkg/retriever` Document/Retriever contracts.

### Changed

- Module path is `github.com/axisvela/praxo-core` (no major suffix while 0.x).

## [0.1.0] - 2026-10-18

### Added

- MIT-licensed framework baseline.
- Model, tool, memory, event, scheduler, policy, sandbox, and agent primitives.
- Minimal governed agent loop with tool calls, event emission, and policy hooks.
- Echo example and framework documentation.
