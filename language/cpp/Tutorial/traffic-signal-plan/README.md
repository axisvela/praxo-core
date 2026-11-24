# C++ traffic signal plan (CT-01)

A bounded first slice of CT-01, not a traffic-control system. It reads fixed
junction queues, drafts a review-only green-time plan and checks it against
deterministic limits. No signal command, live model or city-scale simulation.

Build and run from the repository root:

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build --target praxo-cpp-traffic-signal-plan-tutorial
./language/cpp/build/praxo-cpp-traffic-signal-plan-tutorial --test
./language/cpp/build/praxo-cpp-traffic-signal-plan-tutorial --junction junction-200
./language/cpp/build/praxo-cpp-traffic-signal-plan-tutorial --simulate-failure
```

Expected test output:

```text
success: junction-100 cycle_s=90 green_s=60 within_limits=true status=draft_only commands=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: JUNCTION_UNAVAILABLE reads=1
```

`junction-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, reports `JUNCTION_UNAVAILABLE`, and exits `1`.

`read_junction` returns the fixed `junction-100` cycle of 90 s with limits
`min_green_s=10`/`max_green_s=45`; `draft_signal_plan` returns a 60 s plan
(north 30, east 10, south 20) with `within_limits=true`, `status=draft_only`,
`review_required=true` and `signal_commands=0`. Policy limits the junction and
final `draft_timing` action.

The application remains the owner of traffic control, safety validation, field
integration and any operational command.
