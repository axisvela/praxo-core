# Rust DLP Redaction (CY-06)

Inspect a fixed export and draft a review-only redaction. No production write or external system access.

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
success: export-100 redactable=2 status=draft_only shared=false reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: EXPORT_UNAVAILABLE reads=1
```

No production write or external system access is implemented. Approval and effect
reconciliation belong to the consumer.
