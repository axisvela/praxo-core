# C Tutorials

Bounded C examples built on the native Core. Each tutorial is a small, runnable slice with explicit non-goals and an application-owned boundary; none is a complete industry product.

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

C is a fit when the Agent must live inside an existing native component with caller-owned memory, explicit ABI boundaries and no managed runtime.

- No garbage collector or separate service process is required.
- Function-pointer adapters keep device and transport code application-owned.

Trade-offs and limits:

- The tutorial exercises an in-process adapter, not a serial bus or SDK.
- Binary size, allocation budget and real-time behavior are unmeasured.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by C, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
