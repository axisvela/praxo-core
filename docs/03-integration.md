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

COORDIVELA is an independent product and does not consume PRAXO-CORE. It calls
PRAXOVELA through the product HTTP API for coding execution and owns its own
coordination runtime.

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
