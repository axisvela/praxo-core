# PRAXO-CORE Roadmap

**Current:** `0.15.0` plugin hosts, TCK, manifest v1, and context budgets

**Target:** `1.0.0` stable MIT framework

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

Remaining for 0.3.0:

- context assembly and memory retrieval helpers
- streaming model responses
- tool middleware
- PRAXOVELA compatibility notes

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
