# Python molecule screen (SC-02)

A bounded first slice of [SC-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not drug discovery. It ranks fixed synthetic molecular descriptors under stated
constraints and drafts a review-only assessment. No efficacy, toxicity, synthesis
or clinical claim.

## Why this language and runtime?

- **Selection basis:** A Python research workflow can evaluate native Core without
  introducing a second orchestration runtime; no consumer is verified here.
- **Demonstrated fit:** Async Core callbacks return a precomputed candidate ranking
  and a draft. No chemistry library or descriptor-based ranking is exercised.
- **Choose when:** Learning the tool/policy boundary in an existing Python workflow.
- **Do not choose when:** Seeking validated screening or deciding on a chemistry
  stack. Compare domain libraries and deterministic screening before adding an Agent.
- **Evidence limit:** Core integration fixture only; no docking, ADMET or scientific
  validation follows from the scripted result.

From this directory:

```bash
python app.py --test
python app.py
python app.py --target target-200
python app.py --simulate-failure
```

Expected test output: `Python SC-02 molecule-screen tutorial: all checks passed`.
Both negative commands exit nonzero.

`rank_candidates` returns 4 candidates with `mol-2` on top, `constraints_ok=true`
and illustrative descriptors (MW 342.1, logP 2.4, HBD 2) for `target-100`;
`draft_review` returns `status=draft_only`, `review_required=true`,
`efficacy_claims=0`, `toxicity_claims=0` and `syntheses=0`. Policy limits the
target and final `draft_review` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-target denial, and one read/zero drafts for the simulated molecule-index
outage. Real docking, ADMET prediction, synthesis planning and clinical evaluation
belong to the research team.
