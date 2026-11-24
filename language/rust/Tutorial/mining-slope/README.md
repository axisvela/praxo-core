# Rust mining slope (BE-03)

A bounded first slice of BE-03, not a collapse-prediction or dispatch system. It
reads fixed slope displacement indicators and drafts a review-only alert. No
collapse prediction, mining-vehicle dispatch or safety certification.

Run from this directory:

```bash
cargo run --quiet --locked -- --test
cargo run --quiet --locked --
cargo run --quiet --locked -- --mine mine-200
cargo run --quiet --locked -- --simulate-failure
```

Expected test output:

```text
success: mine-100 sensors=3 displacement_mm=12.4 status=draft_only predictions=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: SLOPE_SOURCE_UNAVAILABLE reads=1
```

`mine-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, reports `SLOPE_SOURCE_UNAVAILABLE`, and exits
`1`.

`read_slope` returns 3 sensors, 12.4 mm displacement against a 10.0 mm threshold
and a rising trend for `mine-100`; `draft_alert` returns
`status=draft_only`, `review_required=true`, `collapse_predictions=0` and
`dispatches=0`. Policy limits the mine and final `draft_alert` action.

Real geotechnical monitoring, predictive models, evacuation and dispatch belong
to the mine operator.
