# PHP tender review (BE-04)

A bounded first slice of [BE-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a bid-submission or collusion-detection system. It validates fixed bid
qualifications and flags document similarities for review. No automatic bid
submission, collusion verdict or live model.

## Why this language and runtime?

- **Selection basis:** A PHP procurement portal could keep a review workflow in
  its existing runtime. No procurement authority integration is verified.
- **Demonstrated fit:** PHP CLI tools return fixed bid qualifications and
  preselected similarity flags; no documents are parsed or compared.
- **Choose when:** Learning native Core integration for an existing PHP portal.
- **Do not choose when:** Seeking qualification scoring or collusion detection.
  Compare deterministic procurement rules and established document-analysis tools.
- **Evidence limit:** Core integration fixture only; no bidder identity, document
  similarity algorithm, submission path or collusion judgment.

Run from the repository root:

```bash
php language/php/Tutorial/tender-review/app.php --test
php language/php/Tutorial/tender-review/app.php
php language/php/Tutorial/tender-review/app.php --tender tender-200
php language/php/Tutorial/tender-review/app.php --simulate-failure
```

Expected test output: `PHP BE-04 tender-review tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_bids` returns 3 bids with 2 qualified and 1 similar document pair for
`tender-100`; `draft_review` returns two flags with `status=draft_only`,
`review_required=true`, `submissions=0` and `collusion_verdicts=0`. Policy limits
the tender and final `draft_flags` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-tender denial, and one read/zero drafts for the simulated bid-index outage.
Real qualification scoring, similarity forensics and collusion judgment belong to
the procurement authority and reviewers.
