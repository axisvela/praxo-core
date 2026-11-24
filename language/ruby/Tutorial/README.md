# Ruby Tutorials

- [Recruiting Match (OP-05)](recruiting-match/README.md): native Ruby Core, fixed
  candidate matching and a review-only shortlist; no outreach or hiring decision.
- [FinOps Review (SE-07)](finops-review/README.md): native Ruby Core, synthetic
  cost calculation and scoped review-only draft; no cloud writes.

The [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
also assigns Ruby candidate paths for supplier risk. Those are planned
assignments, not implemented tutorials.

## Article angle

Productive web and back-office review: expressive code and Rails-era workflows with clear external-system limits.

## Business scenarios

These Ruby examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Ruby community governance (OG-04)](./community-governance/README.md)
- [Ruby due diligence (LJ-03)](./due-diligence/README.md)
- [Ruby FinOps Review (SE-07)](./finops-review/README.md)
- [Ruby lead nurture (CS-02)](./lead-nurture/README.md)
- [Ruby Recruiting Match (OP-05)](./recruiting-match/README.md)
- [Ruby supply-chain review (CY-07)](./supply-chain-review/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Ruby emphasizes developer productivity and expressive code, with Rails and a mature ecosystem for web applications and back-office automation.

Language and ecosystem traits:

- Expressive syntax and productive web frameworks.
- Strong testing culture and readable domain code.
- Good fit for CRUD, admin and workflow-heavy services.

Trade-offs:

- Runtime performance and concurrency need deliberate design.
- Large-team type safety depends on tests and conventions.

Praxo-specific fit: The Core seam fits existing Ruby web/back-office services; the tutorials do not establish cloud, HR or compliance capabilities.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Ruby, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
