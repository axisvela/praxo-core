# TypeScript Meeting Coordination (OP-02)

Reconciles fixed calendar evidence and drafts review-only minutes. No invitations
or live calendar writes.

## Why this language and runtime?

- **Selection basis:** Node/TypeScript commonly hosts calendar and workplace
  integrations; the review step can stay in the same service.
- **Demonstrated fit:** A fixed meeting yields three attendees, two slots, one
  conflict and a draft-only minutes item.
- **Choose when:** Adding a review-only minutes seam beside existing calendar
  tooling.
- **Do not choose when:** Seeking automatic invitations or scheduling. Compare
  the calendar provider and approval policy first.
- **Evidence limit:** One fixed meeting only; no calendar API, invitation, task
  write or scheduling guarantee.

## Run

```bash
npm ci
npm test
```

Expected output:

```text
TypeScript OP-02 meeting-coordination tutorial: all checks passed
```

No calendar API, invitation or task write is implemented. Attendee consent and
scheduling belong to the consumer.
