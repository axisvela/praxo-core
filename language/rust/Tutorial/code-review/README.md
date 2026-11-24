# Rust Code Review (SE-05)

Reviews a fixed diff and dependency manifest, cites findings and uncertainty and
drafts comments. No comments are posted.

## Why this language and runtime?

- **Selection basis:** Rust tooling can keep diff and manifest review beside the
  existing build.
- **Demonstrated fit:** A fixed diff yields two findings, a license concern and a
  draft-only review with no comments posted.
- **Choose when:** Evaluating a review-only audit seam.
- **Do not choose when:** Seeking automated approval or security guarantees.
  Compare the review policy and license process first.
- **Evidence limit:** One fixed diff only; no repository, audit database,
  vulnerability proof or posting. Local validation used `cargo check`; CI is
  configured and pending.

## Run

```bash
cargo run --quiet --locked -- --test
```

Expected output:

```text
success: review-100 findings=2 status=draft_only comments=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: DIFF_UNAVAILABLE reads=1
```

No comment, approval or security finding is posted. Reviewer judgment belongs to
the consumer.
