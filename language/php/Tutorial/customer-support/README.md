# PHP Customer Support (CS-01)

Routes one fixed ticket and drafts a review-only billing reply. No CRM send,
refund or account change.

## Why this language and runtime?

- **Selection basis:** PHP commonly fronts support forms and ticket tooling; the
  review gate can remain in the existing request path.
- **Demonstrated fit:** A deterministic route classifies one billing ticket and
  drafts a reply through scoped tools.
- **Choose when:** Adding a review-only reply draft to a PHP support flow.
- **Do not choose when:** Seeking autonomous refunds or customer messaging.
  Compare current macros and escalation rules first.
- **Evidence limit:** One fixed ticket only; no CRM, send, refund or resolution
  quality claim.

## Run

```bash
php language/php/Tutorial/customer-support/app.php --test
```

Expected output:

```text
PHP CS-01 customer-support tutorial: success, denial and dependency failure passed
```

No CRM, email, refund or account operation is implemented. Escalation, customer
identity and retention belong to the consumer.
