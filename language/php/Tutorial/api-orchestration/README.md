# PHP API Orchestration (SE-08)

A bounded first slice of [SE-08](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a general integration platform. It reads two synthetic upstream APIs (CRM and
ERP), validates the identifier mapping, and drafts a review-only integration
record. This uses the native PHP Core in source mode. No network calls, credentials,
new Core APIs or additional Composer packages are required.

## Why this language and runtime?

- **Selection basis:** PHP integration portals often already own request handling and
  partner credentials, so a mapping review can stay in the same runtime.
- **Demonstrated fit:** Two synthetic upstream responses are mapped and a review-only
  integration record is drafted; no network call or partner system runs.
- **Choose when:** Learning the tool/policy seam for an existing PHP integration layer.
- **Do not choose when:** Seeking live API orchestration or retry semantics. Compare
  the existing integration service and deterministic mapping code first.
- **Evidence limit:** Core integration fixture only; no HTTP, credentials, partner
  sandbox, retry policy or production integration.

Run from the repository root:

```bash
php language/php/Tutorial/api-orchestration/app.php --test
php language/php/Tutorial/api-orchestration/app.php
php language/php/Tutorial/api-orchestration/app.php --customer customer-200
php language/php/Tutorial/api-orchestration/app.php --simulate-failure
```

Expected test output: `PHP SE-08 API-orchestration tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

The deterministic model plans three steps and consumes each result before the next
decision: `read_customer`, then `read_order`, then `draft_integration`. It never
claims autonomous API discovery or arbitrary URL access. Policy limits both
entities and the final mapping id; `requirePolicy` and `requireToolScope` are
enabled. The draft has `status=draft_only`, `review_required=true` and `writes=0`.

Tests assert two upstream reads and one draft on success, zero reads/drafts for a
cross-account denial, and one read/zero drafts for the simulated CRM outage.
A failed tool raises, so no later step or draft executes.

Real authentication, schema negotiation, retries with unknown-effect handling,
idempotency, reconciliation, durable state and any upstream write belong to the
consumer. No real service, publication install, independent consumer, live model
or production verification is claimed.
