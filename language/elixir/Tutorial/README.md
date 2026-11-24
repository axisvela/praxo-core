# Elixir Tutorials

- [Knowledge Maintenance (OP-03)](knowledge-maintenance/README.md): source Elixir
  Core, fixed knowledge diff and a review-only revision draft; no Wiki writes.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional Elixir candidate assignments. Those are planned targets, not
implemented tutorials.

## Article angle

Review boundaries for supervised BEAM services, and the difference between using OTP and merely running on it.

## Business scenarios

These Elixir examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Elixir Knowledge Maintenance (OP-03)](./knowledge-maintenance/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Elixir brings functional programming onto the BEAM, whose supervision trees and lightweight processes target concurrent, fault-tolerant services.

Language and ecosystem traits:

- BEAM supervision and process isolation for failure containment.
- Concurrent request/event handling with immutable data.
- Phoenix and OTP conventions support maintainable service structure.

Trade-offs:

- Dynamic typing and a smaller numerical/ML ecosystem.
- Fault tolerance depends on designing supervision, not just using the runtime.

Praxo-specific fit: The Core seam fits existing Elixir/OTP services; the tutorial does not exercise supervision or concurrency, so it cannot support a BEAM-advantage claim.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Elixir, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
