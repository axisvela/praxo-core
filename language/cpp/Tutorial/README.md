# C++ Tutorials

Bounded C++ examples built on the native Core. Each tutorial is a small, runnable slice with explicit non-goals and an application-owned boundary; none is a complete industry product.

## Business scenarios

These C++ examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [C++ container yard (TL-02)](./container-yard/README.md)
- [C++ EDA placement (OG-05)](./eda-placement/README.md)
- [C++ industrial edge maintenance](./industrial-edge/README.md)
- [C++ materials design (SC-04)](./materials-design/README.md)
- [C++ mesh review (MD-05)](./mesh-review/README.md)
- [C++ molecule screen (SC-02)](./molecule-screen/README.md)
- [C++ ocean routing (TL-03)](./ocean-routing/README.md)
- [C++ traffic signal plan (CT-01)](./traffic-signal-plan/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

C++ is used for industrial software, engines, simulation and latency-sensitive systems that need zero-overhead abstractions and native library access.

Language and ecosystem traits:

- RAII and deterministic lifetimes for device and resource management.
- Templates and inline abstractions without a managed runtime.
- Mature native libraries, compilers and platform SDK integration.

Trade-offs:

- Large language surface and build complexity increase review burden.
- Memory safety and ABI issues remain application responsibilities.

Praxo-specific fit: The native Core seam fits hosts that already manage device or numerical resources; it does not make C++ preferable for simple business workflows.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by C++, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
