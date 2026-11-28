# Dart Tutorials

- [Meeting Coordination (OP-02)](meeting-coordination/README.md): source Dart
  Core, fixed calendar evidence and a review-only minutes/task draft; no invites
  or calendar writes.
- [Onboarding Plan (OP-06)](onboarding-plan/README.md): source Dart Core, fixed
  employee profile and a review-only learning path; no permissions or provisioning.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional Dart candidate assignments. Those are planned targets, not
implemented tutorials.

## Article angle

Client-side Agent patterns for Dart and Flutter products: consent, escalation and review without a remote service.

## Business scenarios

These Dart examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Dart audiobook production (MD-06)](./audiobook-production/README.md)
- [Dart CBT exercise (HC-05)](./cbt-exercise/README.md)
- [Dart chronic care (HC-02)](./chronic-care/README.md)
- [Dart digital twin memory (OG-06)](./digital-twin-memory/README.md)
- [Dart Meeting Coordination (OP-02)](./meeting-coordination/README.md)
- [Dart Onboarding Plan (OP-06)](./onboarding-plan/README.md)
- [Dart waste collection (CT-06)](./waste-collection/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Dart is strongest where one language covers Flutter UI and supporting client or service logic, with sound null safety and fast iteration.

Language and ecosystem traits:

- Single-language UI and application logic via Flutter.
- Sound null safety and approachable async APIs.
- Hot reload and an integrated toolchain for app development.

Trade-offs:

- Server-side ecosystem and operational tooling are smaller than Node/Java.
- Most value depends on an actual Flutter or Dart product.

Praxo-specific fit: The Core seam matters when a mobile or Flutter app must keep review logic in-process; this CLI tutorial does not exercise the UI or platform channels.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Dart, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
