# PRAXO-CORE Architecture

## Layers

```text
Agent loop
  -> model abstraction
  -> tool registry
  -> runtime plugin plane (manifest, hosts, bridges, TCK)
  -> policy hook
  -> event sink
  -> memory store
  -> checkpoint store
  -> sandbox
  -> scheduler contract
  -> HTTP client
```

The agent loop depends only on the interfaces it needs. Plugin hosts, HTTP
clients, schedulers, and sandboxes are adapters supplied by the product or an
external integrator.

## Agent Loop

1. Start a run, apply run middleware, and emit `run.started`.
2. Build the prompt from the system prompt, recalled memory, skills, session
   messages, and the user prompt.
3. Per step:
   - authorize model generation;
   - compact the prompt when a `ContextBudget` is configured;
   - run model middleware and call the model with retry;
   - enforce the token budget;
   - append the assistant message.
4. If the model requests tools:
   - authorize each tool call;
   - run approval/interrupt handling and tool middleware;
   - invoke tools (optionally in parallel) and append results;
   - emit tool events and continue.
5. On a final answer, write the memory record, emit `run.completed`, and return.
6. Fail closed on policy denial.
7. Stop at `MaxSteps`, `MaxTokens`, or `ErrContextBudget`.

## Context Management

Context is managed in layers:

- `Options.MemoryFiles` loads `AGENTS.md` content into the system prompt at
  construction time, bounded by `MaxAgentsMDBytes`.
- `ContextBudget` deterministically keeps recent turns and tool-call/result
  pairs under an estimated token bound.
- `ContextCompactor` can summarize older turns before the deterministic pass;
  `ModelSummarizer` is the built-in model-backed implementation.
- `Offloader` replaces tool results above `OffloadThresholdBytes` with a
  caller-owned reference before they enter the prompt.
- `Options.PromptCache` supplies a provider-neutral `model.CacheHint` for stable
  prefixes; providers may translate it to their cache-control mechanism.

Compaction and offload are observable through `Hooks.OnCompaction` and
`Hooks.OnOffload`.

## Harness Profiles and Evaluation

- `model.ProviderProfile`/`ProfileRegistry` describe context windows, output
  limits, tool/stream/cache support, and tool-call format by model prefix.
- `agent.RubricMiddleware` evaluates a completed run with an `Evaluator` and
  fails the run below `Rubric.PassScore`.
- `sandbox.Interpreter` is the optional in-process script seam; products supply
  the runtime (for example QuickJS) when they need one.

## Agent Middleware Parity

- `StructuredOutput` binds a JSON schema through provider response format or a
  virtual tool, validates the final output, and optionally repairs it.
- `ToolSelectionMiddleware` narrows advertised tools per run;
  `ModelToolSelector` is the built-in model-backed selector.
- `PIIMiddleware` redacts model-bound messages and tool results before they
  enter the prompt.
- `FallbackModel` retries a failed primary model call on a fallback model.
- `CallLimitMiddleware` bounds per-run model and tool calls.
- `pkg/tool.Retry` retries failed tool invocations with the same policy shape.

## Delegation

- `SubagentManager` runs delegated child tasks asynchronously with
  launch/check/update/cancel/list.
- `SubagentIsolated` starts a child with only the request context;
  `SubagentFork` carries the parent message history.
- A runner that implements `ControllableRunner` can accept mid-flight steering.

## Virtual Filesystem

- `pkg/vfs` defines the backend contract (`Stat`, `Read`, `Write`, `List`,
  `Delete`, `Glob`, `Grep`) and an optional `Executor`.
- `pkg/vfs/localfs` confines all paths to one root and rejects traversal,
  sibling prefixes, and symlink escapes.
- `pkg/vfs/vfstools` exposes the backend as `fs.*` tools for the agent loop.

## Plugin Plane

The plugin plane is split at a contract boundary:

- `pkg/plugin` owns Manifest v1, contract kinds, lifecycle, guarded registry,
  scope, limits, and telemetry.
- `pkg/plugin/host/{process,wasm}` own the host implementations and platform
  supervisors.
- `pkg/plugin/bridge` maps a host to `tool.Tool`, `model.Model`, `policy.Hook`,
  `memory.Store`, and `sandbox.Sandbox`.
- `pkg/plugin/tck` asserts lifecycle, registry, framing, timeout, cancellation,
  capability denial, and the not-active gate.

Products own materialization, signature trust, SBOM/evidence, and rolling
updates. The framework never imports product governance.

## Design Rules

- Interfaces first; concrete integrations are adapters.
- No provider credentials in the framework.
- No tenant data in logs.
- No AGPL imports.
- Every exported behavior has a test.
- Event and policy errors propagate; they are not silently dropped.

## Concurrency

The framework is stateless per run. Callers may run multiple agents
concurrently. Shared adapters must provide their own synchronization. Tool
calls within one model response may run concurrently when `MaxParallelTools > 1`
while preserving message order.
