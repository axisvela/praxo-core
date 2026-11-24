# R hedge plan (AE-04)

A bounded first slice of AE-04, not a trading or financial-advice system. It
computes fixed farm exposure and scenario margins in native R and drafts a
review-only hedging plan. No futures orders, price lock or advice.

## Why this language and runtime?

- **Selection basis:** R fits agricultural and financial planning where exposure and
  scenario analysis already use statistical workflows.
- **Demonstrated fit:** Native R compares fixed exposure and scenario margins, then
  drafts a review-only plan; no futures order or price lock runs.
- **Choose when:** Learning review boundaries around existing R scenario analysis.
- **Do not choose when:** Seeking trading or financial advice. Compare market data,
  execution controls and licensed advice first.
- **Evidence limit:** Fixed fixture and Core integration; no market feed, futures
  order, price lock, return guarantee or financial advice.

Run from the repository root:

```bash
Rscript language/r/Tutorial/hedge-plan/hedge.R --test
Rscript language/r/Tutorial/hedge-plan/hedge.R
Rscript language/r/Tutorial/hedge-plan/hedge.R --farm farm-200
Rscript language/r/Tutorial/hedge-plan/hedge.R --simulate-failure
```

Expected test output: `R hedge-plan tutorial: all checks passed`.
Both negative commands exit nonzero.

`analyze_exposure` computes gross 34,400, cost 26,200, margin 8,200, a 10%
downside margin of 4,760 and 2 scenarios for `farm-100`; `draft_hedge_plan`
returns `status=draft_only`, `review_required=TRUE`, `orders=0` and `advice=0`.
Policy limits the farm and final `draft_hedge_plan` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-farm denial, and one read/zero drafts for the simulated farm-data outage.
Real market data, execution, price locks and financial advice belong to the
consumer and licensed advisers.
