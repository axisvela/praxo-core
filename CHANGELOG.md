# Changelog

## [Unreleased]

### Added

- Multilingual SDK design (`docs/17-multilingual-sdk.md`) and roadmap
  (`docs/18-multilingual-roadmap.md`) for Python, TypeScript, and Java SDKs.
- `spec/` scaffold: `SPEC_VERSION`, event/error/schema/plugin wire artifacts,
  `parity.md`, and the conformance-vector format.
- Conformance vectors for the agent loop, toolcall, JSON Schema, plugin,
  memory, event, stream, checkpoint, and policy groups.
- `internal/spec`: the Go vector runner, spec-version checks, wire-reference
  checks, and the parity linter.
- `spec-conformance` CI job.
- `python/praxo`: Python SDK core for model, tool, event, policy, memory,
  checkpoint, agent loop, streaming, and JSON Schema validation.
- `python/praxo/adapters/openaicompat`: OpenAI-compatible adapter with
  non-streaming and SSE streaming paths.
- `python/conformance/run.py` and the `python-conformance` CI job. The Python
  SDK passes all eleven conformance vector groups.
- Python context management: `ContextBudget`, deterministic compaction,
  `ModelSummarizer`, offload hooks, and bounded `AGENTS.md` loading.
- Python middleware: call limits, fallback model, PII redaction, structured
  output, and tool selection, integrated into the agent loop.
- `spec/vectors/context.json`: token estimation, deterministic compaction,
  truncation, and fail-closed budget vectors for Go and Python.
- `spec/vectors/middleware.json`: PII, structured output, call limits, tool
  selection, and fallback vectors for Go and Python.
- `python/API.md`, `python/api-snapshot.py`, and `python/api/0.2.0.txt`.
- Python wheel and sdist build verified in a clean virtual environment.

### Changed

- The contract advances to `SPEC_VERSION` `0.2.0` with the context and
  middleware vector groups.
- The Python SDK advances to `0.2.0` and declares `SPEC_VERSION` `0.2.0`.

### Compatibility

- No Go API changes. `spec/` and the new docs are additive.

## [2.5.0] - 2026-10-24

### Added

- `pkg/conformance`: reusable contract checks for VFS backends, memory stores,
  sandbox runners, event sinks, policy hooks, gateways, models, streaming
  models, tools, and retrievers.
- `conformance.Run` executes named checks and reports all failures in one pass.

### Fixed

- `pkg/vfs/localfs` rejects NUL bytes, Windows drive-relative paths, reserved
  device names, alternate data streams, and trailing dots or spaces.

### Changed

- Added event and OpenTelemetry schema compatibility notes.
- Added the plugin trust and SBOM product handoff checklist.
- Added the workspace/session evaluation and offline E2B, Daytona, OpenSandbox,
  and CubeSandbox adapter modules. The adapters remain optional, untagged
  evaluation modules.

### Compatibility

- `pkg/conformance` is a new additive package.
- Existing exported `pkg/...` declarations are unchanged from 2.4.0.

## [2.4.0] - 2026-10-24

### Added

- `examples/quickstart` streams text deltas through `agent.Options.OnDelta` and
  includes a deterministic SSE regression test. Events are written to stderr.
- `examples/ecosystem/mcp` is a separate module that demonstrates MCP resources
  and prompts with an in-memory server.
- `BenchmarkAgentMemoryRecall` measures recall from a deterministic in-memory
  store.

### Changed

- Quickstart, benchmark, ecosystem, and release docs describe the streaming
  path, memory recall scenario, and optional `adapters/<name>/vX.Y.Z` tags.
- CI runs the new MCP example module in the examples and module-security
  matrices.

### Compatibility

- No exported `pkg/...` API changes; `api/2.4.0.txt` is identical to
  `api/2.3.6.txt`.
- Optional adapter versions are unchanged.

## [2.3.6] - 2026-10-24

### Fixed

- `pkg/formatter`: an empty formatter command returns an error instead of
  panicking, `List`/`AllAvailable`/`Detect` no longer expose shared extension
  slices, and `FormatAll` returns filesystem walk errors.

## [2.3.5] - 2026-10-24

### Fixed

- `pkg/scheduler`: disabling a schedule now rejects callbacks that have not
  started and waits for an in-flight dispatch to finish before returning.

## [2.3.4] - 2026-10-24

### Fixed

- `pkg/tool/jsonschema`: reject `nil` for typed schemas, reject fractional
  values for `integer`, apply `enum` to numeric and boolean values, treat
  `pattern` as a regular expression, and count Unicode code points for length.
- The tool schema boundary is documented explicitly: unsupported `$ref`,
  composition, `additionalProperties`, and `format` keywords are ignored, and a
  `minimum` or `maximum` of zero is treated as unset.

### Changed

- HTTP client tests now cover idempotent retries, non-idempotent server errors,
  cancellation during backoff, disabled body bounds, request-header precedence,
  malformed JSON, and base-URL path joins.

## [2.3.3] - 2026-10-24

### Fixed

- Recheck final tool names and reauthorize changed JSON arguments after
  preparation callbacks, before executing the batch. Original denials still
  stop preparation; unchanged calls keep one tool-policy request.
- Release checks stop on every failed Go command, including race and fuzz
  checks, instead of letting later successes mask failures.

### Changed

- Linux race and vulnerability checks now cover all seven independent adapter
  modules, ecosystem SDK recipes, and the published-module consumer.
- Security support, MCP schema-preserving registration, optional supervisor
  boundaries, and Go 1.26.10 guidance are aligned with the delivered modules.
- No exported `pkg/...` API changes; optional adapter tags are unchanged.

## [2.3.2] - 2026-10-23

### Changed

- Provider and security recipes now document schema-preserving MCP registration,
  static egress routes, policy credential handling, event-data hygiene, and
  sandbox and workspace boundaries.

### Fixed

- `adapters/gemini` streaming now consumes only the first candidate, matching
  the non-streaming response behavior.

## [2.3.1] - 2026-10-23

### Added

- `adapters/a2a`: in-process gRPC client/server round-trip test.

### Changed

- `examples/multiagent` uses `SubagentManager.Wait` instead of polling.
- The sandbox recipe accepts both `[]string` and `[]any` command arguments
  without panicking or referencing an out-of-scope variable.
- The docs workflow builds on pull requests with `mkdocs build --strict`.

### Fixed

- `SubagentManager.Wait` returns the terminal snapshot to every concurrent
  waiter, including when the task is pruned concurrently.

## [2.3.0] - 2026-10-23

### Added

- `delegation.SubagentManager.Wait` blocks until a task reaches a terminal
  state and returns its final snapshot.
- `delegation.SubagentManager.Prune` removes terminal tasks older than a
  caller-supplied duration.
- `adapters/multiagent` waits on completion events instead of polling;
  `Supervisor.PollInterval` is retained but ignored. `MaxConcurrency` bounds
  parallel workers in `Run`.
- `adapters/openaicompat`: opt-in `IncludeUsage` requests streamed token usage
  and maps it into `model.Usage`.

### Changed

- `memory.MemoryStore` generates collision-resistant IDs with a per-store
  counter and precomputes search text on `Put`; the zero value is usable.

### Fixed

- `flow.Parallel` now invokes runnables concurrently while preserving output
  order; it returns the first error by index after all calls finish.
- `delegation.SubagentManager` no longer overwrites completed/failed tasks on
  `Cancel`; `Update` is rejected unless the task is running.
- `adapters/mcp`: resource and prompt listings reject repeated pagination
  cursors; multi-page listing is covered by tests.
- `adapters/a2a`: added an in-process HTTP JSON-RPC client/server round-trip
  test.

## [2.2.0] - 2026-10-23

### Added

- `adapters/otel`: optional OpenTelemetry event sink mapping lifecycle events to
  spans.
- `adapters/anthropic`: native Anthropic Messages adapter with tool calls,
  usage, and SSE streaming.
- `adapters/gemini`: native Gemini generateContent adapter with function calls
  and SSE streaming.
- `adapters/harmovela`: HTTP event sink for Harmovela without importing the
  heavier Harmovela Go module.
- `adapters/a2a`: A2A server executor adapter for exposing a PRAXO-CORE agent to
  agent-to-agent clients.
- `adapters/multiagent`: optional parallel supervisor and sequential delegation
  over `pkg/agent/delegation`.
- `adapters/mcp`: resource and prompt listing/reading helpers in addition to the
  tool gateway.
- `examples/multiagent`: asynchronous subagent delegation, aggregation, and
  cancellation example, plus bilingual multi-agent guidance.
- `examples/plugin`: minimal process plugin host with JSON-Lines and end-to-end
  tests, plus a WASM host smoke example.
- `examples/checkpoint`: in-memory checkpoint store and session resume flow.
- `examples/sandbox`: policy-gated command execution with a strict allowlist.
- `examples/ecosystem-sdk`: AEGIVELA policy, LIMENORA tool-gateway, and RHEOVELA
  workflow recipes.
- Adapter index, bilingual multi-agent guidance, and deeper ecosystem docs.

### Security

- `adapters/otel`: exclude `Event.Data` by default; export only fields explicitly
  selected by `AllowedDataKeys`. Published v0.1.0 exports all event data.

### Fixed

- `adapters/mcp`: add `NewTools` to preserve input schemas in model-visible tool
  specifications; tool discovery follows pagination and rejects repeated cursors.

### Changed

- No `pkg/...` API changes; the `1.0.0` API freeze remains in effect.
- CI and release workflows pin Go `1.26.10` for the `crypto/x509` fix in
  GO-2026-6809.

### Modules

Optional adapter modules are versioned independently:
`adapters/mcp/v0.2.0`, `adapters/otel/v0.2.0`, `adapters/anthropic/v0.1.0`,
`adapters/gemini/v0.1.0`, `adapters/harmovela/v0.1.0`, `adapters/a2a/v0.1.0`,
and `adapters/multiagent/v0.1.0`.

## [2.1.0] - 2026-10-22

### Added

- `adapters/openaicompat`: standard-library OpenAI-compatible model adapter with
  tool calls, tool choice, usage accounting, and SSE streaming.
- `adapters/mcp`: optional module mapping MCP tools to `tool.Gateway`.
- `examples/quickstart`: Ollama and OpenAI-compatible quickstart.
- `examples/reference`: workspace agent with confined VFS tools, policy, memory,
  events, and context budget.
- `examples/ecosystem`: callback-based adapter skeletons for AxisVela components.
- `examples/ecosystem-sdk`: real NOETIVELA, Mnemovela, and GNOSIVELA SDK recipes.
- Agent-loop benchmarks and a benchmark CI job.
- Bilingual docs site, adoption guide, recipes, Chinese documentation, and
  deeper ecosystem comparison.

### Changed

- No `pkg/...` API changes. The `2.0.0` exported surface remains frozen.

### Community

- Added `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, issue/PR templates, and GitHub
  Discussions.

## [2.0.0] - 2026-10-18

### Changed

- Module path is now `github.com/axisvela/praxo-core/v2`; all imports use
  `/v2/pkg/...`.
- No functional API changes: capability packages, root aliases, JSON tags, and
  wire contracts are unchanged.

### Migration

- See `docs/11-migration-v2.md`.

All notable changes to PRAXO-CORE are documented here.

## [1.7.0] - 2026-10-18

### Added

- `agent.ContextEditingMiddleware`: clear old tool results while preserving
  message pairing.
- `agent.TodoList`, `agent.TodoTool`, and `agent.TodoMiddleware`:
  `write_todos` planning state and prompt injection.

## [1.6.0] - 2026-10-18

### Changed

- Split `pkg/agent` into capability packages: `types`, `context`,
  `delegation`, `evaluation`, `hitl`, `stream`, and `middleware`. The root
  package keeps `Agent`, `Options`, `New`, `Run`, and compatibility aliases.

### Added

- `checkpoint.Allowlist`: explicit type registration for persisted payloads
  with `Envelope` and `ErrTypeNotAllowed`.
- `agent.StreamKind`, `agent.StreamPart`, and `Options.OnStream`: typed
  projections for values, updates, messages, tasks, debug, and checkpoints.
  Stream errors abort the run.
- Session-level resume is characterized by `Session.Messages`; durable
  checkpoint storage remains product-owned.

## [1.5.0] - 2026-10-18

### Added

- `agent.InterruptAction`, `agent.InterruptDecision`, and
  `Options.OnInterruptDecision`: approve/edit/reject/respond decisions for
  tool-call interrupts. `OnInterrupt` remains supported for boolean approvals.
- `ErrInterruptDecisionInvalid` for unsupported or incomplete decisions.

## [1.4.0] - 2026-10-18

### Added

- `agent.StructuredOutput`: provider/tool/auto JSON-schema binding with
  validation, optional repair, and a virtual structured-output tool.
- `agent.ToolSelector`, `agent.ToolSelectionMiddleware`, and
  `agent.ModelToolSelector`: per-run tool narrowing with a model-backed
  selector.
- `agent.PIIRule`, `agent.PIIRedactor`, `agent.PIIMiddleware`, and
  `DefaultPIIRules`: model-request and tool-result redaction.
- `agent.FallbackModel`: model middleware that retries a failed primary call on
  a fallback model.
- `agent.CallLimitMiddleware` with `ErrModelCallLimit`/`ErrToolCallLimit`:
  per-run model/tool call budgets.
- `tool.Retry` and `tool.RetryPolicy`: retry middleware for tool invocations.
- `Options` wiring for structured output, fallback model, tool selector, PII
  redactor, call limits, and tool retry.

## [1.3.0] - 2026-10-18

### Added

- `model.ProviderProfile` and `model.ProfileRegistry`: provider/model
  capability profiles with longest-prefix resolution.
- `agent.Rubric`, `agent.Evaluator`, and `agent.RubricMiddleware`: final-output
  rubric evaluation with fail-closed scoring.
- `sandbox.Interpreter` and `sandbox.InterpreterFunc`: optional in-process
  script interpreter seam for products that supply a runtime.

## [1.2.0] - 2026-10-18

### Added

- `pkg/vfs`: virtual filesystem backend contract, entries, matches, and
  optional execution capability.
- `pkg/vfs/localfs`: confined local-directory backend with symlink, traversal,
  and sibling-prefix rejection.
- `pkg/vfs/vfstools`: `fs.list`, `fs.read`, `fs.write`, `fs.edit`, `fs.delete`,
  `fs.glob`, `fs.grep`, and optional `fs.execute` tool adapters.
- `agent.SubagentManager`: asynchronous subagent lifecycle with launch, check,
  update, cancel, and list, plus isolated and fork modes.

## [1.1.0] - 2026-10-18

### Added

- `agent.ContextCompactor` and `agent.ModelSummarizer`: model-based
  summarization of older context before the deterministic budget pass.
- `agent.Offloader` / `agent.OffloadFunc`: replace oversized tool results with
  caller-owned offload placeholders; `OnOffload` reports the replacement.
- `agent.LoadAgentsMD` and `Options.MemoryFiles`: always-loaded `AGENTS.md`
  context, bounded by `MaxAgentsMDBytes`.
- `model.CacheHint` and `Options.PromptCache`: provider-neutral prompt-cache
  hook for stable prefixes.

## [1.0.0] - 2026-10-18

### Changed

- Exported API frozen; see `docs/07-api-freeze.md`.
- Removed the deprecated `pkg/output`, `pkg/format`, and `pkg/tool/schema`
  aliases. Use `pkg/toolcall`, `pkg/formatter`, and `pkg/tool/jsonschema`.
- API snapshot `api/1.0.0.txt`; the diff from `0.16.0` is alias removal only.

### Fixed

- Scheduler callback now updates schedule state under the engine lock and
  dispatches a snapshot, removing the cron data race.
- Process limit tests skip platforms where RLIMIT_AS/RLIMIT_NPROC are not
  reliable against the Go test-binary fixture; Windows Job Object coverage
  remains.

## [0.16.0] - 2026-10-18

### Added

- Fuzz seeds for the manifest, tool-call, JSON Schema, and path parsers.
- CI matrix (Linux/Windows/macOS), race, fuzz, staticcheck, and govulncheck
  jobs.
- `examples/integrator`: a self-contained external-integrator wiring example.
- API snapshot/diff scripts, release-check gate, SBOM/checksums scripts, and a
  tag-triggered release workflow.
- `docs/10-plugin-authoring.md`: Manifest v1, process/WASM protocol, TCK usage.

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
