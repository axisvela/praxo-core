# PRAXO-CORE Roadmap

**Current:** `0.1.0` contract baseline

**Target:** `1.0.0` stable MIT framework

## 0.1.0 - Contract Baseline

Delivered:

- model, tool, memory, event, scheduler, policy, and sandbox interfaces
- governed agent loop
- echo example
- license and provenance rules

## 0.2.0 - Stable Primitives

- Freeze the exported interface set.
- Add conformance tests for every interface.
- Add context assembly and memory retrieval helpers.
- Add streaming model responses.
- Add tool argument schema validation.
- Publish compatibility notes for PRAXOVELA.

Exit gate:

- no breaking interface change without a minor bump
- every primitive has a conformance test
- PRAXOVELA can consume the module through a clean dependency boundary

## 0.3.0 - PRAXOVELA Adapters

- Provider/model adapter bridge.
- Tool registry bridge.
- Memory adapter bridge for Mnemovela.
- Event sink bridge for Harmovela/Argus.
- Policy hook bridge for AEGIVELA.
- Sandbox bridge for Vulcan Forge.

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
