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

## Agent Package Layout

- `pkg/agent` keeps `Agent`, `Options`, `New`, `Run`, and compatibility aliases.
- Capability subpackages: `types`, `context`, `delegation`, `evaluation`,
  `hitl`, `stream`, and `middleware`.
- The root aliases preserve `agent.*` source compatibility; new capabilities
  live in the matching subpackage.

## Agent Middleware Parity

- `StructuredOutput` binds a JSON schema through provider response format or a
  virtual tool, validates the final output, and optionally repairs it.
- `ToolSelectionMiddleware` narrows advertised tools per run;
  `ModelToolSelector` is the built-in model-backed selector.
- `PIIMiddleware` redacts message content, historical tool-call arguments, and
  tool results before they enter the prompt. Live invocation arguments, errors,
  and event payloads remain product-owned.
- `FallbackModel` retries a failed primary model call on a fallback model.
- `CallLimitMiddleware` bounds per-run model and tool calls.
- `ContextEditingMiddleware` clears old tool results without dropping
  message pairs.
- `TodoTool`/`TodoMiddleware` provide `write_todos` planning state and prompt
  injection.
- `pkg/tool.Retry` retries failed tool invocations with the same policy shape.

## Human-in-the-Loop Decisions

- `InterruptDecision` supports approve, edit, reject, and respond.
- `Options.OnInterruptDecision` takes precedence over the legacy boolean
  `OnInterrupt`; edit replaces tool arguments, respond skips execution and
  feeds the human response back to the model.
- Shell sessions, execution policies, and MCP elicitation remain product-owned
  responsibilities; the core only owns the decision contract.

## Runtime Interoperability

- `OnStream` emits typed `StreamPart` projections: values, updates, messages,
  tasks, debug, and checkpoints.
- Stream consumers can persist or forward projections without parsing the
  event sink.
- Session-level resume is expressed by pre-populating `Session.Messages`;
  durable checkpoint storage remains a product concern.
- Graph execution remains RHEOVELA-owned; the core stream is the agent-node
  boundary, not a LangGraph-compatible projection runtime.

## Delegation

- `SubagentManager` runs delegated child tasks asynchronously with
  launch/check/wait/update/cancel/list/prune.
- `SubagentIsolated` starts a child with only the request context;
  `SubagentFork` carries the parent message history.
- A runner that implements `ControllableRunner` can accept mid-flight steering.
- `Cancel` leaves terminal tasks unchanged; `Update` requires a running task.

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

## Language Boundary and Shared Contract

Go remains the reference implementation. The contract that Python, TypeScript,
and Java consume is defined in `spec/` and enforced by a shared conformance
suite:

```text
spec/                    normative contract and vectors
  wire/                  JSON field names, events, errors, plugin envelopes
  vectors/               language-neutral behavior fixtures
  parity.md              Go symbol -> Core symbol inventory
        |
        +-- Go reference implementation (pkg/..., immutable surface)
        +-- Python Core
        +-- TypeScript Core
        +-- Java Core
```

The contract has four layers:

| Layer | Identical across languages | Enforced by |
| --- | --- | --- |
| Wire | yes, byte-for-byte | wire fixtures and snapshot tests |
| Behavior | yes, observably | conformance vectors |
| API surface | one-to-one, idiomatic names | parity linter |
| Conformance | one suite | each Core implementation's CI job |

Source APIs are mapped, not copied. Go interfaces become Python protocols,
TypeScript interfaces, and Java interfaces; `context.Context` becomes the
language cancellation primitive; sentinel errors become stable exception
classes. Concrete adapters, helpers, and package internals are not part of the
contract.

A wire rename, event change, stream-kind change, or plugin envelope change is
breaking for every Core implementation, even if only one Core implementation ships it. See
[Multilingual Core design](../contributing/sdk-design.md) and the
[Core support policy](../languages/support.md).

## Concurrency

The framework is stateless per run. Callers may run multiple agents
concurrently. Shared adapters must provide their own synchronization. Tool
calls within one model response may run concurrently when `MaxParallelTools > 1`
while preserving message order.
