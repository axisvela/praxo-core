# Rust Biodiversity Alerts (AE-05)

Classify fixed labeled observations and draft a ranger review. No production write or external system access.

## Why this language and runtime?

- **Selection basis:** Rust fits deterministic in-process review seams beside
  existing tooling.
- **Demonstrated fit:** A fixed fixture yields a draft-only result with zero
  writes.
- **Choose when:** Evaluating a bounded review seam in an existing Rust service.
- **Do not choose when:** Seeking production effects or external guarantees.
  Compare the existing controls and review policy first.
- **Evidence limit:** One fixed fixture only; no live system, credentials,
  production effect or quality guarantee. Local validation used `cargo check`;
  CI is configured and pending.

## Run

```bash
cargo run --quiet --locked -- --test
```

Expected output:

```text
success: survey-100 flagged=1 status=draft_only pursuit=false reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: OBSERVATION_DATA_UNAVAILABLE reads=1
```

No production write or external system access is implemented. Approval and effect
reconciliation belong to the consumer.
