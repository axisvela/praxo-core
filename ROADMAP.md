# PRAXO-CORE Roadmap

**Current:** `0.15.0` plugin hosts, TCK, manifest v1, and context budgets

**Target:** `1.0.0` stable MIT framework

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

- API stability commitment.
- Production-grade documentation.
- External integrator examples.
- Security review and threat model.
- Release gate, SBOM, and checksums.

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
