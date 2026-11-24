# Rust leak localization (CT-02)

A bounded first slice of CT-02, not a leak-detection or dispatch system. It ranks
fixed synthetic pressure anomalies and drafts a review-only inspection list. No
valve isolation, field dispatch or hydraulic-model guarantee.

## Why this language and runtime?

- **Selection basis:** A Rust utility or edge controller can rank fixed telemetry and
  keep a review boundary in the same deployed binary.
- **Demonstrated fit:** Fixed pressure anomalies are ranked and an inspection list is
  drafted; no hydraulic model, valve or dispatch path runs.
- **Choose when:** Learning the Core seam in an existing Rust utility tool.
- **Do not choose when:** Seeking leak validation or isolation. Compare hydraulic
  analysis, field procedures and the SCADA system first.
- **Evidence limit:** Core integration fixture only; no live pressure data, hydraulic
  model, valve isolation, dispatch or leak guarantee.

Run from this directory:

```bash
cargo run --quiet --locked -- --test
cargo run --quiet --locked --
cargo run --quiet --locked -- --network network-200
cargo run --quiet --locked -- --simulate-failure
```

Expected test output:

```text
success: network-100 segments=5 anomalies=2 status=draft_only valve_commands=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: NETWORK_SOURCE_UNAVAILABLE reads=1
```

`network-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, reports `NETWORK_SOURCE_UNAVAILABLE`, and exits
`1`.

`read_anomalies` returns 5 segments, 2 anomalies ranked `seg-3`/`seg-1` at medium
confidence for `network-100`; `draft_inspection` returns
`status=draft_only`, `review_required=true`, `valve_commands=0` and
`dispatches=0`. Policy limits the network and final `draft_inspection` action.

Real hydraulic modeling, leak validation, valve isolation and field dispatch
belong to the utility operator.
