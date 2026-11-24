# Java Clinical Guidelines (HC-01)

A bounded tutorial slice over the native Java Core. It reads one fixed fixture,
enforces scope and drafts a review-only result. No production write or external
system access.

## Why this language and runtime?

- **Selection basis:** Java fits enterprise services where review logic can stay
  in the existing JVM process.
- **Demonstrated fit:** A fixed fixture yields a draft-only result with zero
  writes through scoped tools and policy.
- **Choose when:** Evaluating a review seam in an existing Java service.
- **Do not choose when:** Seeking production effects or external guarantees.
  Compare the existing controls and review policy first.
- **Evidence limit:** One fixed fixture only; no live system, credentials,
  production effect or quality guarantee. Local validation used `mvn test`; CI is
  configured and pending.

## Run

```bash
mvn -q test
```

The test covers success, policy denial and dependency failure.

No production write or external system access is implemented. Approval and effect
reconciliation belong to the consumer.
