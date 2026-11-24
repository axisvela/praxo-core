# Erlang Tutorials

- [AIOps RCA (SE-06)](aiops-rca/README.md): source Erlang Core, fixed correlated
  signals and a review-only rollback draft; no remediation or live telemetry.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional Erlang candidate assignments. Those are planned targets, not
implemented tutorials.

## Business scenarios

These Erlang examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Erlang AIOps RCA (SE-06)](./aiops-rca/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Erlang's BEAM runtime and OTP behaviours come from telecom-grade concurrency, isolation and distributed supervision requirements.

Language and ecosystem traits:

- Soft real-time scheduling and lightweight processes.
- Supervision, distribution and hot-code concepts built into OTP.
- Long operational heritage in telecom and messaging.

Trade-offs:

- Syntax and hiring base are narrower than mainstream languages.
- General numerical and UI ecosystems are limited.

Praxo-specific fit: The Core seam fits existing OTP operations software; the sequential escript tutorial does not demonstrate supervision, distribution or fault recovery.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Erlang, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
