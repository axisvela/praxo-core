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

## What It Is Not

- PRAXOVELA the product
- COORDIVELA the coordination control plane
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

COORDIVELA is independent and does not consume PRAXO-CORE.

PRAXOVELA remains an AGPL product. The MIT framework is a separate work so it
can be embedded without AGPL obligations.
