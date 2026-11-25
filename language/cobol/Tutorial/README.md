# COBOL Tutorials

Application tutorials live in `Tutorial/`, alongside focused `language/go/examples/`.

- [Bank batch exception review](batch-exception-review/README.md): reuse the
  existing deterministic batch handoff fixture; a separate COBOL review worker
  handles public/private records, with unavailable and timeout paths.

COBOL tutorials keep the main batch deterministic. Review is a separate,
application-owned step, not an inline model decision in the posting path.

## Article angle

Primary planned enhancement: end-of-day decimal reconciliation and exception
review in the existing batch host. See [runtime-aligned design](https://axisvela.github.io/praxo-core/getting-started/runtime-scenario-design/).

Adding reviewed Agent assistance beside an existing COBOL batch without rewriting the business flow or moving sensitive records.

## Business scenarios

These Cobol examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [COBOL Bank Batch Exception Review](./batch-exception-review/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

COBOL persists in banking, insurance and government batch/transaction estates where decimal arithmetic and existing operational knowledge matter.

Language and ecosystem traits:

- Strong fixed/decimal data handling for business records.
- Readable record layouts and long-lived batch conventions.
- Deep integration with existing mainframe operations and staff skills.

Trade-offs:

- Tooling, testing and hiring are narrower than modern general-purpose stacks.
- Refactoring and web/API integration usually need surrounding systems.

Praxo-specific fit: The Core is useful only as a governed review beside an existing COBOL flow; the tutorial deliberately keeps the batch and worker in place.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Cobol, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
