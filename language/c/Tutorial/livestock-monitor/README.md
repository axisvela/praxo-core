# C Livestock Monitor (AE-01)

Summarizes fixed animal observations and drafts a review-only veterinary
request. No diagnosis, isolation or feeding control.

## Why this language and runtime?

- **Selection basis:** A C component can run on farm gateways with constrained
  memory and known transports.
- **Demonstrated fit:** Fixed observations yield one flagged animal and a
  draft-only review request with zero treatments.
- **Choose when:** Evaluating a bounded herd-review seam.
- **Do not choose when:** Seeking diagnosis or automated feeding. Compare
  veterinary procedures and farm controls first.
- **Evidence limit:** One fixed herd only; no sensor feed, diagnosis, treatment,
  isolation or feeding effect. Local validation used `gcc -fsyntax-only` only;
  CI is configured and pending.

## Run

```bash
cc -std=c11 -Ilanguage/c/include language/c/Tutorial/livestock-monitor/main.c \
  -Llanguage/c/build -lpraxo_core -lm -o build/livestock-monitor
./build/livestock-monitor --test
```

Expected output:

```text
success: herd-100 flagged=1 status=draft_only treatments=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: OBSERVATION_DATA_UNAVAILABLE reads=1
```

No diagnosis, treatment or feeding control is implemented. Veterinary approval
and animal identity belong to the consumer.
