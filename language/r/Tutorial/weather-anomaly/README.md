# R weather anomaly (SC-05)

A bounded first slice of SC-05, not an operational forecast or warning service. It
computes fixed time-series anomalies in native R and drafts a review-only notice.
No operational forecast, warning issuance or disaster dispatch.

Run from the repository root:

```bash
Rscript language/r/Tutorial/weather-anomaly/weather.R --test
Rscript language/r/Tutorial/weather-anomaly/weather.R
Rscript language/r/Tutorial/weather-anomaly/weather.R --region region-200
Rscript language/r/Tutorial/weather-anomaly/weather.R --simulate-failure
```

Expected test output: `R weather-anomaly tutorial: all checks passed`.
Both negative commands exit nonzero.

`analyze_series` computes a 20.2 °C median baseline, max deviation 5.8 °C against
a 2.5 threshold and 1 anomaly over 5 days for `region-100`; `draft_notice`
returns `status=draft_only`, `review_required=TRUE`, `forecasts=0` and
`dispatches=0`. Policy limits the region and final `draft_notice` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-region denial, and one read/zero drafts for the simulated weather-series
outage. Real forecasting, meteorological validation and emergency dispatch belong
to the weather service.
