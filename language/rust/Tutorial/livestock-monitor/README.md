# Rust livestock monitor (AE-01)

A bounded first slice of AE-01, not a veterinary or feeding-control system. It
summarizes fixed animal observations and drafts a review-only veterinary request.
No diagnosis, isolation or feeding control.

## Why this language and runtime?

- **Selection basis:** A Rust farm or sensor gateway can summarize observations
  without adding a separate managed runtime.
- **Demonstrated fit:** Fixed herd data produces a review-only veterinary request;
  no diagnosis, isolation or feeding control runs.
- **Choose when:** Learning the Core seam in an existing Rust agriculture tool.
- **Do not choose when:** Seeking diagnosis or feeding automation. Compare the farm's
  sensor stack, veterinary process and direct rules first.
- **Evidence limit:** Core integration fixture only; no live sensors, diagnosis,
  isolation, feeding control or animal-health guarantee.

Run from this directory:

```bash
cargo run --quiet --locked -- --test
cargo run --quiet --locked --
cargo run --quiet --locked -- --herd herd-200
cargo run --quiet --locked -- --simulate-failure
```

Expected test output:

```text
success: herd-100 animals=40 flagged=2 status=draft_only diagnoses=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: HERD_SOURCE_UNAVAILABLE reads=1
```

`herd-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, reports `HERD_SOURCE_UNAVAILABLE`, and exits
`1`.

`read_herd` returns 40 animals with 2 flagged for `reduced_feed` at low
confidence for `herd-100`; `draft_request` returns
`status=draft_only`, `review_required=true`, `diagnoses=0` and
`feed_controls=0`. Policy limits the herd and final `draft_review_request`
action.

Real sensor integration, veterinary diagnosis, isolation and feeding control
belong to the producer and veterinarian.
