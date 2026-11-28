# Python Tutorials

Application-shaped tutorials live here, alongside `language/go/examples/`, which keeps
mechanism checks and focused integration examples. Tutorial is intentionally
capitalized in directory paths.

- [Bug repair](bug-repair/README.md): seeded defect, review-only in-memory patch
  and fixture test rerun; no real repository or PR.
- [Recruiting match](recruiting-match/README.md): fixed candidates, deterministic
  skill/year ranking and a review-only shortlist; no outreach.
- [Order review](order-review/README.md): native Core, policy and HTTP tools over
  a shared synthetic service; first deterministic slice, not a full Web app.
- [Office Q&A](office-qa/README.md): fixed documents and citation-bearing answer.
- [Insurance claims](insurance-claims/README.md): draft-only decision with
  `StructuredOutput` validation.
- [Legal compliance](legal-compliance/README.md): HITL approval gate with a
  simulated publish.
- [Education tutoring](education-tutoring/README.md): Core `Retriever` and a
  draft-only study plan.
- [CBT exercise](cbt-exercise/README.md): fixed exercise with an explicit
  crisis-escalation branch and no therapist replacement.
- [Molecule screen](molecule-screen/README.md): fixed molecular
  descriptors, review-only assessment and no efficacy claim.
- [Virtual PI](virtual-pi/README.md): fixed research tasks, shared
  budget, review-only coordination and no validity claim.
- [Precedent outline](precedent-outline/README.md): fixed precedents,
  review-only cited outline and no judicial decision.
- [Dubbing plan](dubbing-plan/README.md): fixed licensed media, review-only
  caption plan and no voice cloning.
- [Biodiversity alerts](biodiversity-alerts/README.md): fixed labeled
  observations, review-only ranger alert and no pursuit.
- [Pollution tracing](pollution-tracing/README.md): fixed sensor traces,
  review-only hypotheses and no enforcement finding.
- [Patent FTO](patent-fto/README.md): fixed claim overlap, counsel
  questions only and no legal opinion.
- [Phishing awareness](phishing-awareness/README.md): fixed email indicators,
  review-only awareness exercise and no deceptive sends.
- [Trial screening](trial-screening/README.md): fixed patient criteria, review-only
  screening note and no enrollment.
- [Clinical guidelines](clinical-guidelines/README.md): fixed guideline citations,
  review-only summary and abstain on missing evidence.
- [Credit diligence](credit-diligence/README.md): fixed ratios and a review-only
  credit memo.

Shared business backends live in the public
[agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services)
repository; they are not part of the Core package or wire spec.

## Article angle

Ecosystem-first Agents with explicit limits: readability, data libraries and the cost of dynamic typing at scale.

## Business scenarios

These Python examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Python biodiversity alerts (AE-05)](./biodiversity-alerts/README.md)
- [Python CBT exercise (HC-05)](./cbt-exercise/README.md)
- [Python Clinical Guidelines (HC-01)](./clinical-guidelines/README.md)
- [Python Credit Diligence (FC-03)](./credit-diligence/README.md)
- [Python dubbing plan (MD-04)](./dubbing-plan/README.md)
- [Python education tutoring](./education-tutoring/README.md)
- [Python insurance claims triage](./insurance-claims/README.md)
- [Python legal compliance memo](./legal-compliance/README.md)
- [Python molecule screen (SC-02)](./molecule-screen/README.md)
- [Python Office Q&A](./office-qa/README.md)
- [Order Review Agent](./order-review/README.md)
- [Python patent FTO (LJ-02)](./patent-fto/README.md)
- [Python phishing awareness (CY-04)](./phishing-awareness/README.md)
- [Python pollution tracing (CT-05)](./pollution-tracing/README.md)
- [Python precedent outline (LJ-04)](./precedent-outline/README.md)
- [Python Trial Screening (HC-03)](./trial-screening/README.md)
- [Python virtual PI (OG-07)](./virtual-pi/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Python's readability and enormous ecosystem make it the default for data, ML, automation and rapid prototyping across many industries.

Language and ecosystem traits:

- Low learning curve and clear syntax for mixed teams.
- Broad libraries for data, science, web, ML and automation.
- Strong interactive and notebook-based exploration.

Trade-offs:

- Interpreter performance, the GIL and packaging can constrain scale.
- Dynamic typing shifts more validation into tests and runtime checks.

Praxo-specific fit: The Core seam fits existing Python data and automation code; the tutorials use fixtures and do not establish clinical, legal or scientific validity.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Python, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
