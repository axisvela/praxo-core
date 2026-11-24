# PHP Public Approval (CT-03)

A bounded first slice of [CT-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a government identity or approval system. It validates a fixed application's
documents and drafts parallel review tasks. No official approval, document upload
or live model.

## Why this language and runtime?

- **Selection basis:** A PHP government or enterprise portal can keep a review workflow
  in its existing request and deployment model.
- **Demonstrated fit:** Fixed application documents produce review-only parallel tasks;
  no identity check, document upload or official approval runs.
- **Choose when:** Learning the Core seam in an existing PHP portal.
- **Do not choose when:** Seeking official approval or agency integration. Compare the
  existing case-management system and statutory process first.
- **Evidence limit:** Core integration fixture only; no identity verification, agency
  system, document authenticity, official decision or legal effect.

Run from the repository root:

```bash
php language/php/Tutorial/public-approval/app.php --test
php language/php/Tutorial/public-approval/app.php
php language/php/Tutorial/public-approval/app.php --application application-200
php language/php/Tutorial/public-approval/app.php --simulate-failure
```

Expected test output: `PHP CT-03 public-approval tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_application` returns three fixed documents with one missing
(`proof-of-address`) and agencies `tax`/`housing`; `draft_review_tasks` returns
`status=draft_only`, `review_required=true` and `approvals=0`. Policy limits the
application and final `parallel_review` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-application denial, and one read/zero drafts for the simulated registry
outage. Real identity, document verification, agency systems and official
approvals belong to the consumer.
