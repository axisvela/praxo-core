# Rust lab loop (SC-03)

A bounded first slice of SC-03, not an autonomous laboratory. It replays a fixed
parameter/result loop with deterministic limits and drafts review-only next
parameters. No laboratory actuator, chemical handling or closed-loop control.

## Why this language and runtime?

- **Selection basis:** A Rust instrument-control component can keep a bounded planning
  loop next to its device code. No laboratory consumer is verified.
- **Demonstrated fit:** Fixed parameter/result iterations produce review-only next
  parameters with explicit safety limits; no actuator or chemistry runs.
- **Choose when:** Evaluating the Core seam in an existing Rust lab tool.
- **Do not choose when:** Seeking closed-loop control or chemical handling. Compare
  the instrument SDK and laboratory safety interlocks first.
- **Evidence limit:** Core integration fixture only; no instrument, actuator, chemical
  handling, safety certification or closed-loop optimization.

Run from this directory:

```bash
cargo run --quiet --locked -- --test
cargo run --quiet --locked --
cargo run --quiet --locked -- --lab lab-200
cargo run --quiet --locked -- --simulate-failure
```

Expected test output:

```text
success: lab-100 iterations=3 best_result=0.72 status=draft_only actuators=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: LAB_SOURCE_UNAVAILABLE reads=1
```

`lab-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, reports `LAB_SOURCE_UNAVAILABLE`, and exits `1`.

`read_loop` returns 3 iterations, temperature 80 °C/time 30 min, best result 0.72
and `limits_ok=true` for `lab-100`; `draft_plan` returns iteration 4
(85 °C/25 min) with `status=draft_only`, `review_required=true`, `actuators=0`
and `chemicals=0`. Policy limits the lab and final `draft_next_parameters`
action.

Real instrument control, chemistry, safety interlocks and experimental design
belong to the laboratory.
