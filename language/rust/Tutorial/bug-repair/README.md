# Rust Bug Repair (SE-02)

Reproduces a fixed bug, drafts a patch and reruns a fixture test. No PR creation
or repository write.

## Why this language and runtime?

- **Selection basis:** Rust services often own build and test tooling; the repair
  review can stay in-process.
- **Demonstrated fit:** A fixed bug reproduces, a draft patch reruns `pass`, and
  zero writes or PRs occur.
- **Choose when:** Evaluating a review-only repair seam beside existing Rust
  tooling.
- **Do not choose when:** Seeking autonomous commits or PRs. Compare the test
  harness and review policy first.
- **Evidence limit:** One fixed bug only; no repository, build system, test suite
  or patch application. Local validation used `cargo check`; CI is configured and
  pending.

## Run

```bash
cargo run --quiet --locked -- --test
```

Expected output:

```text
success: bug-100 reproduced=yes rerun=pass status=draft_only writes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: BUG_SOURCE_UNAVAILABLE reads=1
```

No repository write or PR is implemented. Merge approval belongs to the
consumer.
