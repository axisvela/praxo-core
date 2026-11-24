# Nim Tutorials

- [Maintenance Triage (IN-01)](maintenance-triage/README.md): source Nim Core,
  fixed sensor telemetry and a review-only work-order draft; no device control or
  validated failure prediction.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional Nim candidate assignments. Those are planned targets, not
implemented tutorials.

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

Nim fits small native utilities that want an embedded Core with a compact toolchain and C-backend deployment.

- The maintenance example reads fixed telemetry and drafts a work order.
- Native callbacks keep the sensor boundary application-owned.

Trade-offs and limits:

- No sensor feed, prediction or work-order write.
- Binary size and memory behavior are not measured.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Nim, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
