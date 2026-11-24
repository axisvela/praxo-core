# Rust Tutorials

Bounded Rust examples built on the native Core. Each tutorial is a small, runnable slice with explicit non-goals and an application-owned boundary; none is a complete industry product.

## Business scenarios

These Rust examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Rust cold chain (TL-04)](./cold-chain/README.md)
- [Rust construction safety (BE-01)](./construction-safety/README.md)
- [Rust household robot (PE-04)](./household-robot/README.md)
- [Rust IoT gateway diagnosis](./iot-gateway/README.md)
- [Rust lab loop (SC-03)](./lab-loop/README.md)
- [Rust leak localization (CT-02)](./leak-localization/README.md)
- [Rust livestock monitor (AE-01)](./livestock-monitor/README.md)
- [Rust mining slope (BE-03)](./mining-slope/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Rust fits edge, security and native infrastructure where explicit ownership and a single deployable binary matter.

- Trait-based adapters keep device and network contracts application-owned.
- Examples cover gateways, security, fleet, lab and field review.

Trade-offs and limits:

- Most examples are in-process fixtures, not protocol or device integrations.
- No binary-size, latency or safety-certification measurement.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Rust, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
