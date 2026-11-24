# Nim Livestock Monitor (AE-01)

Summarizes fixed animal observations and drafts a review request. No veterinary
diagnosis, isolation or feeding control.

## Why this language and runtime?

- **Selection basis:** A Nim utility can run on farm gateways and embed Core
  without a larger runtime.
- **Demonstrated fit:** Native callbacks summarize one fixed herd and draft one
  review-only request.
- **Choose when:** Evaluating a bounded review step in an existing Nim herd tool.
- **Do not choose when:** Seeking diagnosis, isolation or automated feeding.
  Compare veterinary procedures and current farm controls first.
- **Evidence limit:** Fixed observations only; no sensor feed, diagnosis,
  treatment, isolation or feeding effect. Local validation used `nim check` only;
  CI is configured and pending.

## Build and run

```bash
nim check --path:language/nim/src --hints:off language/nim/Tutorial/livestock-monitor/livestock.nim
nim c --path:language/nim/src --hints:off --out:build/nim-livestock-monitor language/nim/Tutorial/livestock-monitor/livestock.nim
./build/nim-livestock-monitor --test
./build/nim-livestock-monitor
./build/nim-livestock-monitor --herd herd-200
./build/nim-livestock-monitor --simulate-failure
```

Expected test output:

```text
success: herd-100 flagged=1 status=draft_only treatments=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: OBSERVATION_DATA_UNAVAILABLE reads=1
```

No diagnosis, treatment, isolation or feeding control is implemented. Animal
identity, veterinary approval and effect reconciliation belong to the consumer.
