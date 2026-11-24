# Lua Tutorials

Bounded Lua examples built on the native Core. Each tutorial is a small, runnable slice with explicit non-goals and an application-owned boundary; none is a complete industry product.

## Article angle

Embedding governance in host applications: tiny runtime, C integration and host-owned authority.

## Business scenarios

These Lua examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Lua aquaculture water (AE-03)](./aquaculture-water/README.md)
- [Lua Host Embedding](./host-embedding/README.md)
- [Lua irrigation plan (IN-06)](./irrigation-plan/README.md)
- [Lua live show (MD-07)](./live-show/README.md)
- [Lua storyboard previs (MD-01)](./storyboard-previs/README.md)
- [Lua world economy (MD-03)](./world-economy/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Lua is built for embedding: a tiny interpreter, a simple C API and fast startup make it common in games, appliances and host applications.

Language and ecosystem traits:

- Small embeddable runtime with a stable C interface.
- Simple syntax and fast startup for host-side scripting.
- Widely used for configuration and extension points.

Trade-offs:

- Small standard library and limited general-purpose ecosystem.
- Dynamic typing and tooling demand disciplined host boundaries.

Praxo-specific fit: The Core seam fits products that already expose Lua extension points; this CLI tutorial does not embed a real host or measure footprint.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Lua, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
