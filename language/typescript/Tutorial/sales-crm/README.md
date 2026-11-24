# TypeScript Sales CRM (CS-03)

Extracts fixed objections from a transcript and drafts a review-only CRM update.
No CRM write or customer message.

## Why this language and runtime?

- **Selection basis:** TypeScript fits CRM integrations and transcript tooling;
  the review seam can stay in the existing service.
- **Demonstrated fit:** One fixed call yields two objections and a draft-only
  update with zero CRM writes.
- **Choose when:** Adding a review-only follow-up draft to a sales tool.
- **Do not choose when:** Seeking automated CRM writes or outreach. Compare the
  CRM policy and human review first.
- **Evidence limit:** One fixed transcript only; no live audio, CRM, customer
  message or sales outcome.

## Run

```bash
npm ci
npm test
```

Expected output:

```text
TypeScript CS-03 sales-crm tutorial: all checks passed
```

No CRM, email or call platform is accessed. Customer consent and review belong
to the consumer.
