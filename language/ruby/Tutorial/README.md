# Ruby Tutorials

- [Recruiting Match (OP-05)](recruiting-match/README.md): native Ruby Core, fixed
  candidate matching and a review-only shortlist; no outreach or hiring decision.
- [FinOps Review (SE-07)](finops-review/README.md): native Ruby Core, synthetic
  cost calculation and scoped review-only draft; no cloud writes.

The [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
also assigns Ruby candidate paths for supplier risk. Those are planned
assignments, not implemented tutorials.

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

Ruby fits web applications, back-office tools and automation where the team already deploys and maintains Ruby services.

- Native Core runs with ordinary Ruby objects and policy lambdas.
- Examples cover FinOps, recruiting, governance, outreach and diligence.

Trade-offs and limits:

- No cloud credentials, HR decisions or external sends.
- No production adoption, performance or compliance claim.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Ruby, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
