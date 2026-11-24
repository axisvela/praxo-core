# R fire spread (AE-02)

A bounded first slice of AE-02, not a fire-warning or dispatch system. It computes
fixed weather/fuel spread indicators in native R and drafts a review-only spread
report. No operational warning, evacuation order or firebreak dispatch.

Run from the repository root:

```bash
Rscript language/r/Tutorial/fire-spread/fire.R --test
Rscript language/r/Tutorial/fire-spread/fire.R
Rscript language/r/Tutorial/fire-spread/fire.R --cell cell-200
Rscript language/r/Tutorial/fire-spread/fire.R --simulate-failure
```

Expected test output: `R fire-spread tutorial: all checks passed`.
Both negative commands exit nonzero.

`analyze_spread` computes 4 cells, wind 18 km/h, fuel 0.7, slope 5 and a 1.51
spread indicator for `cell-100`; `draft_spread_report` returns 2 scenarios with
`status=draft_only`, `review_required=TRUE`, `warnings=0` and `dispatches=0`.
Policy limits the cell and final `draft_spread_report` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-cell denial, and one read/zero drafts for the simulated cell-data outage.
The indicator is illustrative, not a validated fire model. Real weather data,
fire-behavior science and incident command belong to the consumer.
