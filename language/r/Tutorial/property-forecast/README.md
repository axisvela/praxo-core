# R property forecast (BE-05)

A bounded first slice of BE-05, not a valuation or investment-advice system. It
computes fixed site metrics in native R, shows forecast assumptions and drafts a
review-only forecast. No verified probability, return guarantee or
personal-location profiling.

Run from the repository root:

```bash
Rscript language/r/Tutorial/property-forecast/property.R --test
Rscript language/r/Tutorial/property-forecast/property.R
Rscript language/r/Tutorial/property-forecast/property.R --site site-200
Rscript language/r/Tutorial/property-forecast/property.R --simulate-failure
```

Expected test output: `R property-forecast tutorial: all checks passed`.
Both negative commands exit nonzero.

`analyze_site` computes 240,000 gross rent, 120,000 net income, a 0.067 forecast
yield, 2 scenarios and three stated assumptions for `site-100`;
`draft_forecast` returns `status=draft_only`, `review_required=TRUE`,
`probabilities=0` and `return_claims=0`. Policy limits the site and final
`draft_forecast` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-site denial, and one read/zero drafts for the simulated site-data outage.
Real market data, valuation, probability modeling and investment decisions
belong to the consumer.
