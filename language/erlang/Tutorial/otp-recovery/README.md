# Erlang OTP Recovery (SE-06)

A bounded OTP supervision tutorial. It starts a real `one_for_one` supervisor and
worker, injects one child crash, observes the restarted PID and start count, then
lets Core choose a review action from that evidence. No production cluster is
touched.

## Why this language and runtime?

- **Selection basis:** Erlang/OTP is common in telecom and messaging operations
  where process isolation, supervision and recovery are runtime primitives.
- **Demonstrated fit:** `supervisor` starts a real child, the tutorial sends a crash,
  and the test asserts a new PID plus `worker_starts >= 2` before drafting.
- **Choose when:** An existing OTP service needs a governed recovery-review seam.
- **Do not choose when:** A sequential script or a non-BEAM service is sufficient.
  The runtime advantage must come from actual supervision, not just syntax.
- **Evidence limit:** Local supervisor and one injected crash only; no production
  cluster, distribution, hot upgrade, backoff tuning, persistence or live model.

## Run

Compile the Core and tutorial modules, then from the repository root:

```bash
mkdir -p language/erlang/build/ebin
erlc -I language/erlang/src -o language/erlang/build/ebin language/erlang/src/*.erl
erlc -o language/erlang/build/ebin \
  language/erlang/Tutorial/otp-recovery/worker.erl \
  language/erlang/Tutorial/otp-recovery/praxo_sup.erl
escript language/erlang/Tutorial/otp-recovery/recovery.escript --test
escript language/erlang/Tutorial/otp-recovery/recovery.escript
escript language/erlang/Tutorial/otp-recovery/recovery.escript --service service-200
escript language/erlang/Tutorial/otp-recovery/recovery.escript --simulate-failure
```

Expected test output includes a supervisor report, then:

```text
success: service-100 recovered=true worker_starts=2 status=draft_only reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: SUPERVISION_UNAVAILABLE reads=1
Erlang otp-recovery tutorial: all checks passed
```

`service-200` is denied before the tool runs. `--simulate-failure` returns
`SUPERVISION_UNAVAILABLE` with one read and no draft.
