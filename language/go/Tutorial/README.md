# Go Tutorials

Bounded Go examples built on the native Core. Each tutorial is a small, runnable slice with explicit non-goals and an application-owned boundary; none is a complete industry product.

## Article angle

Simple concurrency, static deployment and reference governance: why Go is a natural first runtime for embedded Agents.

## Business scenarios

These Go examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Go customs reroute](./customs-reroute/README.md)
- [Go emergency route plan](./emergency-route-plan/README.md)
- [Go evidence-vault review](./evidence-vault/README.md)
- [Go full-stack workspace](./fullstack-workspace/README.md)
- [Go incident coordination](./incident-coordination/README.md)
- [Go litigation timeline](./litigation-timeline/README.md)
- [Go logistics checkpoint and resume](./logistics-checkpoint/README.md)
- [Go pentest lab review](./pentest-lab-review/README.md)
- [Go SOC alert triage](./soc-alert-triage/README.md)
- [Go Zero-Trust Policy Review (CY-05)](./zero-trust-review/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Go is designed for simple, maintainable services: goroutines and channels make concurrency approachable, net/http is production-standard, and static binaries simplify deployment.

Language and ecosystem traits:

- Straightforward concurrency with goroutines and channels.
- Strong standard library and networking/HTTP tooling.
- Fast builds, static binaries and simple cross-compilation.

Trade-offs:

- Generics and expressiveness are more limited than some languages.
- Garbage collection and runtime behavior still require measurement.

Praxo-specific fit: Go is also the reference Core, so the tutorials show canonical behavior; its service and tooling strengths make the examples natural, but they remain fixtures rather than performance or production evidence.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Go, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
