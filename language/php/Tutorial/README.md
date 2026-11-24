# PHP Tutorials

- [Localization Draft (CS-07)](localization-draft/README.md): native PHP Core,
  fixed rules and review-only localized text; no legal/tax guarantee.
- [Lead Nurture (CS-02)](lead-nurture/README.md): native PHP Core, fixed
  business profiles and review-only opt-in outreach; no crawling or sends.
- [Tender Review (BE-04)](tender-review/README.md): native PHP Core, fixed
  bid qualifications and review-only similar-document flags; no bid submission.
- [Copyright Evidence (LJ-05)](copyright-evidence/README.md): native PHP Core,
  fixed authorized assets and review-only evidence packet; no notice filing.
- [Public Approval (CT-03)](public-approval/README.md): native PHP Core, fixed
  application documents and review-only parallel tasks; no official approval.
- [Internal Service Desk (OP-01)](internal-service-desk/README.md): native PHP
  Core, fixed employee request and a review-only approval draft; no provisioning.
- [API Orchestration (SE-08)](api-orchestration/README.md): native PHP Core, two
  synthetic upstream APIs plus a review-only mapping draft; no network or writes.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional PHP candidate assignments. Those are planned targets, not
implemented tutorials.

## Business scenarios

These PHP examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [PHP API Orchestration (SE-08)](./api-orchestration/README.md)
- [PHP copyright evidence (LJ-05)](./copyright-evidence/README.md)
- [PHP customs reroute (TL-05)](./customs-reroute/README.md)
- [PHP Internal Service Desk (OP-01)](./internal-service-desk/README.md)
- [PHP lead nurture (CS-02)](./lead-nurture/README.md)
- [PHP localization draft (CS-07)](./localization-draft/README.md)
- [PHP Public Approval (CT-03)](./public-approval/README.md)
- [PHP tender review (BE-04)](./tender-review/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

PHP fits web portals and back-office applications that want the Agent inside their existing request and deployment model.

- The native Core is used directly with source loading in these examples.
- Examples cover service desks, approvals, integrations, procurement and content review.

Trade-offs and limits:

- All upstream systems are fixtures; no portal or agency integration.
- No production identity, filing, send or compliance decision.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by PHP, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
