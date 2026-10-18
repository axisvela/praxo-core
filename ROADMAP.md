# PRAXO-CORE Roadmap

**Current:** `1.2.0` delegation and execution parity (2026-10-18)

**Target:** `1.3.0` harness parity

## Release History

| Version | Focus |
| --- | --- |
| 0.1.0 | model, tool, memory, event, scheduler, policy, sandbox, agent loop |
| 0.2.0 | scheduler, output, schema, flow, prompt, retriever |
| 0.3.0 | provider, tool, memory, event, policy, and sandbox adapters; formatter registry |
| 0.4.0 | agent lifecycle status |
| 0.5.0 | checkpoint contracts |
| 0.6.0 | streaming and retry |
| 0.7.0 | parallel tools and panic-safe invocation |
| 0.8.0 | tool choice, allowlists, token budget, recall |
| 0.9.0 | `agent.New(Options)` and system prompt |
| 0.10.0 | skills, response format, interrupts, run context, session store |
| 0.11.0 | profiles and model middleware |
| 0.12.0 | agent middleware stack |
| 0.13.0 | shared HTTP client |
| 0.14.0 | plugin contract layer |
| 0.15.0 | plugin hosts, Manifest v1, TCK, path containment, context budget |
| 0.16.0 | canonical `toolcall`/`formatter`/`jsonschema` paths with deprecated aliases |
| 1.0.0 | API freeze, plugin hosts, TCK, security and release gates |
| 1.1.0 | model summarization, tool-result offload, AGENTS.md memory, prompt-cache hook |
| 1.2.0 | virtual filesystem backend/tools and async/fork subagent manager |

See `CHANGELOG.md` for exact changes.

## 0.1.0 - Contract Baseline

Delivered:

- model, tool, memory, event, scheduler, policy, and sandbox interfaces
- governed agent loop
- echo example
- license and provenance rules

## 0.2.0 - Framework Primitives (released 2026-10-18)

Delivered:

- [x] Extract the scheduler engine from PRAXOVELA and migrate PRAXOVELA to the
  framework scheduler.
- [x] Extract tool-call parsing and JSON Schema validation from PRAXOVELA.
- [x] Add Runnable/Chain/Parallel composition.
- [x] Add prompt templates.
- [x] Add retriever contracts.
- [x] Unambiguous 0.x module path (`github.com/axisvela/praxo-core`).

Exit gate:

- no breaking interface change without a minor bump
- every primitive has a conformance test
- PRAXOVELA can consume the module through a clean dependency boundary

## 0.3.0 - PRAXOVELA Adapters (released 2026-10-18)

- [x] Tool specs, middleware, and ordered wrapping.
- [x] Event fan-out and filter sinks.
- [x] In-memory memory store and context assembler.
- [x] Provider/model adapter bridge (`ChatModel`).
- [x] Tool registry bridge (`Gateway`).
- [x] Memory adapter bridge (`RemoteStore`/`Backend`).
- [x] Event sink bridge (`PublisherSink`).
- [x] Policy hook adapter (`FuncHook`).
- [x] Sandbox adapter (`FuncSandbox`).
- [x] Context assembly and memory retrieval helpers.
- [x] Streaming model responses.
- [x] Tool middleware.
- [x] PRAXOVELA compatibility notes.
- PRAXOVELA product wiring for the bridges.

Exit gate:

- PRAXOVELA can build against PRAXO-CORE without importing internal packages.
- Adapter compatibility tests pass.

## 0.5.0 - Durable Scheduling and Recovery

- Durable schedule contract.
- Lease/fencing helpers.
- Run checkpoint and resume hooks.
- Idempotency keys for tool calls and events.
- Failure and retry semantics.

Exit gate:

- restart recovery test
- duplicate-firing prevention test
- policy-denial fail-closed test

## 1.0.0 - Stable Framework

- API stability commitment and exported API freeze inventory.
- Production-grade documentation and external integrator examples.
- Security review and threat model.
- Release gate, SBOM, and checksums.
- No competitive harness-parity expansion; the items below are post-1.0.

## 1.1.0 - Context Management Parity (released 2026-10-18)

- `ContextCompactor` interface with model-based summarization and large-result
  offload.
- Always-loaded `AGENTS.md` memory loader.
- Prompt-cache hooks for Anthropic/Bedrock-compatible providers.

Exit gate:

- a long-run test exceeds one context window without silent context loss
- compaction and offload are observable and bounded

## 1.2.0 - Delegation and Execution Parity (released 2026-10-18)

- Async subagent lifecycle: launch, check, update, cancel.
- Explicit forked subagent context mode.
- Virtual filesystem backend protocol (state, store, filesystem, composite).
- Dedicated `delete`, `glob`, and `grep` tool surface.

Exit gate:

- async subagent and virtual-filesystem backend conformance tests
- subagent cancellation and fork-context tests

## 1.3.0 - Harness Profiles and Evaluation

- Provider/harness profiles for tool-call quirks, context windows, and caching.
- Rubric/evaluation middleware.
- Optional in-process JavaScript interpreter.

Exit gate:

- provider-profile conformance tests
- rubric and interpreter tests

## Non-Goals

- PRAXOVELA product assembly
- model hosting
- memory storage
- workflow engine
- verification authority
- coordination control plane

## Consumers

| Consumer | Integration |
| --- | --- |
| PRAXOVELA | embeds the framework; remains AGPL |
| external products | direct interface implementation |
