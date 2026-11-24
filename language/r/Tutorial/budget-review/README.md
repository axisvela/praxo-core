# R budget review (CT-07)

A bounded first slice of CT-07, not an official audit. It computes budget
execution for a fixed synthetic programme, explains a flagged variance and
drafts a review-only performance finding. No real disbursement data, official
audit conclusion or live model.

## Why this language and runtime?

- **Selection basis:** R fits public-finance analytics where ledger summaries and
  variance calculations already run in statistical workflows.
- **Demonstrated fit:** Native R computes budget execution and a review-only finding;
  no ledger reconciliation or audit opinion is produced.
- **Choose when:** Learning review boundaries around existing R calculations.
- **Do not choose when:** Seeking an official audit or disbursement truth. Compare the
  finance system, audit standards and deterministic controls first.
- **Evidence limit:** Fixed fixture and Core integration; no public ledger, audit
  judgment, official reporting or accounting-standard compliance.

Run from the repository root:

```bash
Rscript language/r/Tutorial/budget-review/budget.R --test
Rscript language/r/Tutorial/budget-review/budget.R
Rscript language/r/Tutorial/budget-review/budget.R --program program-200
Rscript language/r/Tutorial/budget-review/budget.R --simulate-failure
```

Expected test output: `R budget-review tutorial: all checks passed`.
Both negative commands exit nonzero.

`analyze_execution` computes a 1,000,000 budget, 820,000 disbursed, 82%
execution, 18% variance, 4 milestones with 3 completed and an `underspend` flag
for `program-100`; `draft_review` returns two findings with
`status=draft_only`, `review_required=TRUE` and `audit_conclusions=0`. Policy
limits the programme and final `draft_finding` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-programme denial, and one read/zero drafts for the simulated budget-data
outage. Real ledger reconciliation, audit judgment and official reporting belong
to the consumer.
