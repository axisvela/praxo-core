# Nim Tutorials

- [Maintenance Triage (IN-01)](maintenance-triage/README.md): source Nim Core,
  fixed sensor telemetry and a review-only work-order draft; no device control or
  validated failure prediction.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional Nim candidate assignments. Those are planned targets, not
implemented tutorials.

## Article angle

Small native utilities with explicit boundaries: compile-to-C deployment and application-owned device contracts.

## Business scenarios

These Nim examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Nim Maintenance Triage (IN-01)](./maintenance-triage/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Nim combines Python-like syntax with native compilation through C/C++, metaprogramming and optional safety checks.

Language and ecosystem traits:

- Readable syntax with compile-time metaprogramming.
- Native performance and straightforward C interoperability.
- Small binaries and flexible memory-management choices.

Trade-offs:

- Smaller ecosystem, libraries and hiring pool.
- Toolchain and package conventions are less standardized.

Praxo-specific fit: The Core seam fits small native Nim utilities; the fixture does not establish sensor integration, prediction or deployment-size benefits.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Nim, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
