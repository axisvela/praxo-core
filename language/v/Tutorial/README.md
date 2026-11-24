# V Tutorials

- [Release Preflight](release-preflight/README.md): native V reads a temporary
  configuration, validates fields/version/entry and drafts review corrections; no
  deployment.
- [Production Scheduling (IN-02)](production-scheduling/README.md): source V Core,
  fixed job queue, deterministic priority order and a review-only instruction
  draft; no dispatch or MES integration.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional V candidate assignments. Those are planned targets, not implemented
tutorials.

## Article angle

Primary direction: [configuration and release preflight](release-preflight/README.md),
not production scheduling. See [runtime-aligned design](https://axisvela.github.io/praxo-core/getting-started/runtime-scenario-design/).

Compact native tools with a review seam: fast compilation and small binaries, minus ecosystem hype.

## Business scenarios

These V examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [V Production Scheduling (IN-02)](./production-scheduling/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

V targets simple, fast-compiled native programs with a small language surface and safety-oriented defaults.

Language and ecosystem traits:

- Simple syntax and very fast compilation.
- Native binaries without a heavy runtime.
- C interoperability and optional safety checks.

Trade-offs:

- Young ecosystem, libraries and tooling stability.
- Limited evidence for large-scale production adoption.

Praxo-specific fit: The Core seam fits small native V tools; the example does not establish MES integration or performance advantage.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by V, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
