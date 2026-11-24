# Java Tutorials

Application tutorials live in `Tutorial/`, alongside focused `examples/`.

- [Order review](order-review/README.md): native Core, scoped HTTP tools and a
  loopback Web entry point over the shared synthetic order service.

Business APIs are teaching contracts, not additions to Core's public API.

## Business scenarios

These Java examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Java Order Review Web Agent](./order-review/README.md)
- [Java Wealth Review Service](./wealth-service/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Java combines a mature JVM with a very broad enterprise ecosystem, strong tooling and long-term platform support.

Language and ecosystem traits:

- JIT performance and a mature concurrent runtime.
- Extensive libraries, frameworks and Maven/Gradle tooling.
- Long-standing enterprise and regulated-industry adoption.

Trade-offs:

- Startup and memory footprint can exceed lighter runtimes.
- Verbosity and framework layering increase maintenance cost.

Praxo-specific fit: The Core seam fits existing JVM services with HTTP and identity boundaries; the loopback tutorial does not establish production performance or ERP support.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Java, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
