# C Tutorials

Bounded C examples built on the native Core. Each tutorial is a small, runnable slice with explicit non-goals and an application-owned boundary; none is a complete industry product.

## Article angle

Governed Agent loops inside constrained native components: what stays caller-owned, and why predictable memory matters more than framework surface.

## Business scenarios

These C examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [C constrained host diagnostic component](./device-diagnostics/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

C remains the default for operating-system interfaces, firmware and native libraries that must expose a stable ABI and predictable memory use.

Language and ecosystem traits:

- Minimal runtime and direct hardware/OS access.
- Stable ABI and broad compiler/toolchain availability.
- Explicit ownership and allocation make costs visible.

Trade-offs:

- Manual memory management raises defect and review cost.
- Portable tooling and package management are comparatively limited.

Praxo-specific fit: The Core seam is attractive only where a C host already owns the device or OS contract; the tutorial demonstrates that seam, not a C advantage for business orchestration.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by C, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
