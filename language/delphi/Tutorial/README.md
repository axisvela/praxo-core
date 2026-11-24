# Delphi / Free Pascal Tutorials

- [RPA Reconciliation (OP-04)](rpa-reconciliation/README.md): source Delphi/Free
  Pascal Core, fixed PO/invoice reconciliation and a review-only exception.
- [Legacy Migration (SE-03)](legacy-migration/README.md): source Delphi/Free Pascal
  Core, fixed legacy inventory and a review-only migration plan; no automated
  refactoring or production migration.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional Delphi candidate assignments. Those are planned targets, not
implemented tutorials.

## Article angle

Incremental Agent adoption in long-lived Delphi and Free Pascal applications instead of platform replacement.

## Business scenarios

These Delphi examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Delphi HVAC settings (BE-02)](./hvac-settings/README.md)
- [Delphi / Free Pascal Legacy Migration (SE-03)](./legacy-migration/README.md)
- [Delphi / Free Pascal RPA Reconciliation (OP-04)](./rpa-reconciliation/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Delphi and Free Pascal serve long-lived Windows desktop, industrial and database applications with rapid visual development and native deployment.

Language and ecosystem traits:

- RAD tooling and native Windows executables.
- Strong database/desktop heritage and incremental migration paths.
- Free Pascal provides a source-compatible open toolchain.

Trade-offs:

- Proprietary tooling and platform focus narrow deployment options.
- Modern web, cloud and package ecosystems are comparatively limited.

Praxo-specific fit: The Core seam fits existing Delphi desktop software; it is not a recommendation to start new cross-platform services in Delphi.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Delphi, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
