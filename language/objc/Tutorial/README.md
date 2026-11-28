# Objective-C Tutorials

- [Privacy Agent (PE-03)](privacy-agent/README.md): source Objective-C Core,
  fixed message-exposure classification and a review-only deletion request; no
  password handling, account access or deletion execution.
- [Chronic Care (HC-02)](chronic-care/README.md): fixed wearable trends and a
  review-only alert; no dosage or individualized treatment change.
- [DLP Redaction (CY-06)](dlp-redaction/README.md): fixed export inspection and a
  review-only redaction draft; no encryption or DLP completeness claim.
- [Digital Twin Memory (OG-06)](digital-twin-memory/README.md): consent-scoped
  fixed memories with provenance and one deletion; no inbox or password access.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional Objective-C candidate assignments. Those are planned targets, not
implemented tutorials.

## Article angle

Privacy review inside existing Apple applications: Foundation integration without mailbox, password or deletion access.

## Business scenarios

These Objective-C examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Objective-C Privacy Agent (PE-03)](./privacy-agent/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Objective-C remains relevant for existing Apple platform code, with direct access to Foundation, Cocoa and the mature iOS/macOS runtime.

Language and ecosystem traits:

- Deep Foundation/Cocoa and platform API integration.
- Dynamic runtime and long-established Apple tooling.
- Large body of existing macOS/iOS application code.

Trade-offs:

- Swift is the forward direction for most new Apple development.
- Verbose syntax and manual memory/ARC conventions add maintenance cost.

Praxo-specific fit: The Core seam fits existing Objective-C apps; the privacy fixture does not exercise account access, deletion or platform privacy guarantees.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Objective-C, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
