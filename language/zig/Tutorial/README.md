# Zig Tutorials

Bounded Zig examples built on the native Core. Each tutorial is a small, runnable slice with explicit non-goals and an application-owned boundary; none is a complete industry product.

## Article angle

Primary planned enhancement: C ABI host-health callbacks with allocation-budget
and cleanup checks. See [runtime-aligned design](https://axisvela.github.io/praxo-core/getting-started/runtime-scenario-design/).

Explicit control at the edge: allocators, comptime and C interoperability, with pre-1.0 trade-offs stated plainly.

## Business scenarios

These Zig examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Zig drone fleet plan (TL-01)](./drone-fleet-plan/README.md)
- [Zig small gateway health check](./gateway-health/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Zig emphasizes explicit control, compile-time execution and C interoperability without hidden allocations or control flow, targeting systems and embedded use.

Language and ecosystem traits:

- Explicit allocators and no hidden control flow.
- Compile-time metaprogramming via comptime.
- Direct C ABI/library interoperability.

Trade-offs:

- Pre-1.0 language/tooling churn and a small ecosystem.
- Explicit control shifts more responsibility to the developer.

Praxo-specific fit: The Core seam fits constrained Zig components; the fixture does not measure binary size, memory ceilings or platform guarantees.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Zig, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
