# PRAXO-CORE Integration

## With PRAXOVELA

PRAXOVELA is the first product built on PRAXO-CORE. The product supplies:

- provider/model routing
- tool registry and sandbox assembly
- session/run persistence and checkpoint stores
- HTTP/SSE API
- durable scheduler
- desktop shell
- policy and approval enforcement
- plugin materialization, signature trust, SBOM/evidence, and rolling updates

The framework supplies the plugin contract layer, process/WASM hosts, generic
host bridges, and the conformance kit. PRAXOVELA imports the hosts through thin
aliases so product behavior stays unchanged.

`pkg/httpclient` is reusable by product adapters; vendor-specific auth, tenant
policy, grant/epoch semantics, and trust stores remain product-owned.

## With External Integrators

External integrators can implement the framework interfaces directly:

- model adapter for their provider
- tool adapters for their capabilities
- memory adapter for their store
- event adapter for their bus
- policy adapter for their authorization system
- sandbox adapter for their execution environment
- checkpoint store for durable resume
- plugin host/bridge wiring for their runtime

## Non-Goals

- Do not import PRAXOVELA internal packages.
- Do not duplicate PRAXOVELA's product assembly.
- Do not make the framework own durable schedule firing.
- Do not self-certify verification.
- Do not put provider credentials, tenant policy, or trust stores in the
  framework.
