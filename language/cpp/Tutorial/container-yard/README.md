# C++ container yard (TL-02)

A bounded first slice of TL-02, not a terminal operating system. It replans fixed
synthetic container jobs under resource constraints and drafts a review-only
schedule. No crane or AGV command, live terminal feed or throughput guarantee.

Build and run from the repository root:

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build --target praxo-cpp-container-yard-tutorial
./language/cpp/build/praxo-cpp-container-yard-tutorial --test
./language/cpp/build/praxo-cpp-container-yard-tutorial --yard yard-200
./language/cpp/build/praxo-cpp-container-yard-tutorial --simulate-failure
```

Expected test output:

```text
success: yard-100 jobs=8 assigned=8 status=draft_only crane_commands=0 agv_commands=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: YARD_UNAVAILABLE reads=1
```

`yard-200` is denied by policy and exits `2`; `--simulate-failure` reads once,
reports `YARD_UNAVAILABLE`, and exits `1`.

`read_yard` returns 8 jobs, 2 cranes and 3 AGVs for `yard-100`; `draft_plan`
returns 8 assigned jobs with `status=draft_only`, `review_required=true`,
`crane_commands=0` and `agv_commands=0`. Policy limits the yard and final
`draft_schedule` action.

Real terminal telemetry, crane/AGV control, safety interlocks and throughput
optimization belong to the terminal operator.
