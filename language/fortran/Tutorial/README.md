# Fortran Tutorials

Bounded Fortran examples built on the native Core. Each tutorial is a small, runnable slice with explicit non-goals and an application-owned boundary; none is a complete industry product.

## Article angle

Keeping numerical work in Fortran while adding a review-only Agent boundary for simulation interpretation.

## Business scenarios

These Fortran examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Fortran simulation metrics review](./simulation-metrics/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Fortran remains central in numerical simulation, HPC and scientific codebases with mature array semantics and optimized compilers.

Language and ecosystem traits:

- Array-first syntax and numerical library heritage.
- HPC compiler and accelerator ecosystem.
- Long-lived scientific code and domain expertise.

Trade-offs:

- General application, web and package ecosystems are limited.
- Tooling and interoperability can lag modern general-purpose stacks.

Praxo-specific fit: The Core seam fits simulation hosts that should not move numerical work; the tutorial does not establish solver, HPC or performance capability.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Fortran, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
