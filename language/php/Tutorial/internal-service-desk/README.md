# PHP Internal Service Desk (OP-01)

A bounded first slice of [OP-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an identity or provisioning system. It reads a fixed employee request,
classifies the risk, and drafts a review-only approval. No account changes,
software installation or live model are used.

## Why this language and runtime?

- **Selection basis:** A PHP intranet or admin portal can add a review step without a
  separate agent service or identity system.
- **Demonstrated fit:** A fixed employee request produces a review-only approval draft;
  no account provisioning or ticket write runs.
- **Choose when:** Learning the tool/policy seam in an existing internal PHP portal.
- **Do not choose when:** Seeking IAM provisioning or service-desk integration. Compare
  the existing identity workflow and ticketing rules first.
- **Evidence limit:** Core integration fixture only; no employee directory, permissions,
  provisioning, ticket update or approval authority.

Run from the repository root:

```bash
php language/php/Tutorial/internal-service-desk/app.php --test
php language/php/Tutorial/internal-service-desk/app.php
php language/php/Tutorial/internal-service-desk/app.php --employee employee-200
php language/php/Tutorial/internal-service-desk/app.php --simulate-failure
```

Expected test output: `PHP OP-01 internal-service-desk tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

The deterministic model plans three steps and consumes each result: `read_request`
returns a fixed employee-100 software-install request with `risk=low`;
`draft_approval` returns `status=draft_only`, `review_required=true` and
`provisions=0`. Policy limits the employee and the final `approve` action;
`requirePolicy` and `requireToolScope` are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-employee denial, and one read/zero drafts for the simulated request-source
outage. Real identity, HR/IT systems, provisioning, approvals and audit
reconciliation belong to the consumer.
