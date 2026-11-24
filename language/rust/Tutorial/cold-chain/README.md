# Rust cold chain (TL-04)

A bounded first slice of TL-04, not a refrigeration-control or clinical-cargo
system. It computes fixed temperature excursions and drafts a review-only
transfer review. No refrigeration change, actuator access or clinical guarantee.

Run from this directory:

```bash
cargo run --quiet --locked -- --test
cargo run --quiet --locked --
cargo run --quiet --locked -- --shipment cold-200
cargo run --quiet --locked -- --simulate-failure
```

Expected test output:

```text
success: cold-100 max_c=9.5 excursion_minutes=25 status=draft_only changes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: COLD_SOURCE_UNAVAILABLE reads=1
```

`cold-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, reports `COLD_SOURCE_UNAVAILABLE`, and exits
`1`.

`read_shipment` returns 2 sensors, 6 readings, min -2.0 °C, max 9.5 °C against an
8.0 °C threshold and 25 excursion minutes for `cold-100`; `draft_review` returns
`status=draft_only`, `review_required=true`, `refrigeration_changes=0` and
`clinical_guarantees=0`. Policy limits the shipment and final
`draft_transfer_review` action.

Real telemetry, refrigeration control, cargo integrity and clinical suitability
belong to the consumer.
