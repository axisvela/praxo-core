# PRAXO-CORE Integration

## With PRAXOVELA

PRAXOVELA is the first product built on PRAXO-CORE. The product supplies:

- provider/model routing
- tool registry and sandbox assembly
- session/run persistence
- HTTP/SSE API
- durable scheduler
- desktop shell
- policy and approval enforcement

## With COORDIVELA

COORDIVELA has two integration paths:

1. **Execution path (default):** call the PRAXOVELA HTTP API to start coding
   runs. PRAXO-CORE is not involved directly.
2. **Coordinator path:** embed PRAXO-CORE for the coordinator's own reasoning
   loop and tools, while still sending code execution to PRAXOVELA.

## With External Integrators

External integrators can implement the framework interfaces directly:

- model adapter for their provider
- tool adapters for their capabilities
- memory adapter for their store
- event adapter for their bus
- policy adapter for their authorization system
- sandbox adapter for their execution environment

## Non-Goals

- Do not import PRAXOVELA internal packages.
- Do not duplicate PRAXOVELA's product assembly.
- Do not make the framework own durable schedule firing.
- Do not self-certify verification.
