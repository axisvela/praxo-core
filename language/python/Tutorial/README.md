# Python Tutorials

Application-shaped tutorials live here, alongside `examples/`, which keeps
mechanism checks and focused integration examples. Tutorial is intentionally
capitalized in directory paths.

- [Order review](order-review/README.md): native Core, policy and HTTP tools over
  a shared synthetic service; first deterministic slice, not a full Web app.
- [Office Q&A](office-qa/README.md): fixed documents and citation-bearing answer.
- [Insurance claims](insurance-claims/README.md): draft-only decision with
  `StructuredOutput` validation.
- [Legal compliance](legal-compliance/README.md): HITL approval gate with a
  simulated publish.
- [Education tutoring](education-tutoring/README.md): Core `Retriever` and a
  draft-only study plan.
- [Trial screening](trial-screening/README.md): fixed patient criteria, review-only
  screening note and no enrollment.
- [Clinical guidelines](clinical-guidelines/README.md): fixed guideline citations,
  review-only summary and abstain on missing evidence.
- [Credit diligence](credit-diligence/README.md): fixed ratios and a review-only
  credit memo.

Shared business backends live in the public
[agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services)
repository; they are not part of the Core package or wire spec.
