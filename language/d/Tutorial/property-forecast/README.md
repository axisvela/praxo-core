# D property forecast (BE-05)

A bounded first slice of BE-05, not a valuation or investment-advice system. It
computes fixed site metrics in native D, shows the forecast assumptions and drafts
a review-only forecast. No verified probability, return guarantee or
personal-location profiling.

## Why this language and runtime?

- **Selection basis:** A D analytics or property tool can retain native calculation and
  review in one deployment. No real-estate consumer is verified.
- **Demonstrated fit:** Fixed site metrics produce a review-only forecast; no market
  data, valuation model or probability calibration runs.
- **Choose when:** Learning the Core seam around existing D calculations.
- **Do not choose when:** Seeking valuation or investment advice. Compare direct D or R
  analysis and the underwriting process first.
- **Evidence limit:** Core integration fixture only; no market feed, valuation,
  probability guarantee, return claim or location profiling.

Run from the repository root:

```bash
dmd -i -Ilanguage/d/source -run language/d/Tutorial/property-forecast/forecast.d --test
dmd -i -Ilanguage/d/source -run language/d/Tutorial/property-forecast/forecast.d
dmd -i -Ilanguage/d/source -run language/d/Tutorial/property-forecast/forecast.d --site site-200
dmd -i -Ilanguage/d/source -run language/d/Tutorial/property-forecast/forecast.d --simulate-failure
```

Expected test output:

```text
success: site-100 gross=240000 net=120000 yield=0.067 status=draft_only probabilities=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: SITE_UNAVAILABLE reads=1
```

`site-200` is denied by policy before the tool is called and exits nonzero.
`--simulate-failure` reads once, reports `SITE_UNAVAILABLE`, and exits nonzero.

`read_site` returns 8000 footfall, 240,000 gross rent, 120,000 net income, a
0.067 forecast yield and 2 scenarios for `site-100`; `draft_forecast` returns
`status=draft_only`, `review_required=true`, `probabilities=0` and
`return_claims=0`. Policy limits the site and final `draft_forecast` action.

Real market data, valuation, probability modeling and investment decisions belong
to the consumer.
