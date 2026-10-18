# PRAXO-CORE Overview

PRAXO-CORE is the MIT-licensed agent framework behind PRAXOVELA. It exists so
that AxisVela products and external integrators can build governed agents
without rebuilding the agent loop, provider abstraction, tool contracts, memory
boundary, event boundary, or scheduler contract.

## What It Is

- a small Go framework
- provider-neutral
- tool-driven
- memory-aware
- event-observable
- policy-gated
- sandbox-ready
- checkpointable
- plugin-extensible through the frozen runtime plugin contract

## What It Is Not

- PRAXOVELA the product
- a model provider
- a memory database
- a workflow engine
- a verification system

## Relationship

```text
praxo-core (MIT)
  |
  +-- PRAXOVELA (AGPL product)
  +-- external integrators
```

PRAXOVELA remains an AGPL product. The MIT framework is a separate work so it
can be embedded without AGPL obligations.

## Runtime Plugin Plane

`pkg/plugin` defines the contract kinds, Manifest v1, lifecycle FSM, guarded
adapter registry, per-plugin scope, resource limits, and telemetry. Process and
WASM hosts live under `pkg/plugin/host`, generic bridges under
`pkg/plugin/bridge`, and the conformance kit under `pkg/plugin/tck`.
Materialization, signature trust, SBOM/evidence, and rolling updates remain
product-owned.
