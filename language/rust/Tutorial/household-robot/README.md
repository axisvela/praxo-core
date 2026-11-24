# Rust household robot (PE-04)

A bounded first slice of PE-04, not a robot controller. It observes fixed robot
state with freshness, drafts a bounded review-only action that requires cancel
confirmation, and records zero hardware commands. No hardware access or safety
certification.

## Why this language and runtime?

- **Selection basis:** A Rust robotics host might embed Core without adding a
  separate orchestration runtime. No ROS 2 or hardware consumer is verified here.
- **Demonstrated fit:** A typed adapter and trait-based tool boundary return fixed
  observation data and a draft action with explicit freshness and cancel fields.
- **Choose when:** Evaluating the Core seam in an existing Rust control component.
- **Do not choose when:** Seeking perception, motion planning or hardware control.
  Compare direct Rust robotics stacks against actual device and safety requirements.
- **Evidence limit:** Core integration only; no ROS 2, real-time runtime, safety
  certification, hardware command or comparative performance claim.

Run from this directory:

```bash
cargo run --quiet --locked -- --test
cargo run --quiet --locked --
cargo run --quiet --locked -- --robot robot-200
cargo run --quiet --locked -- --simulate-failure
```

Expected test output:

```text
success: robot-100 age_ms=200 fresh=true authority=bounded status=draft_only commands=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: ROBOT_SOURCE_UNAVAILABLE reads=1
```

`robot-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, reports `ROBOT_SOURCE_UNAVAILABLE`, and exits
`1`.

`read_state` returns a 200 ms old, fresh observation with joints OK in the kitchen
for `robot-100`; `draft_action` proposes `pick` with
`authority=bounded`, `cancel_required=true`, `status=draft_only`,
`review_required=true`, `hardware_commands=0` and `safety_claims=0`. Policy
limits the robot and final `draft_action` action.

Real perception, motion planning, safety interlocks and hardware control belong
to the robotics platform.
