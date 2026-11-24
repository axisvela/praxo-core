# Swift Cbt Exercise (HC-05)

A bounded tutorial slice over the native Swift Core. It reads one fixed fixture,
enforces scope and drafts a review-only result. No production write or external
system access.

## Why this language and runtime?

- **Selection basis:** Swift fits Apple-platform services where a review seam can
  stay in-process.
- **Demonstrated fit:** A fixed fixture yields a draft-only result with zero
  writes through scoped tools and policy.
- **Choose when:** Evaluating a review seam in an existing Swift app.
- **Do not choose when:** Seeking production effects or external guarantees.
  Compare the existing controls and review policy first.
- **Evidence limit:** One fixed fixture only; no live system, credentials,
  production effect or quality guarantee. This tutorial was not run locally in
  the current environment; CI is configured and pending.

## Run

```bash
swift run praxo-cbt-exercise-tutorial --test
```

Expected output:

```text
success: session-100 status=draft_only writes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: SESSION_DATA_UNAVAILABLE reads=1
```

No production write or external system access is implemented. Approval and effect
reconciliation belong to the consumer.
