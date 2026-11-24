# TypeScript Phishing Awareness (CY-04)

Classifies a fixed synthetic email and drafts an authorized review-only
awareness exercise. No sends, links or infrastructure attacks.

## Why this language and runtime?

- **Selection basis:** TypeScript fits security-awareness tooling; the review
  step can stay beside existing mail tooling.
- **Demonstrated fit:** One fixed email yields two signals and a draft-only
  exercise with no emails sent.
- **Choose when:** Evaluating a bounded awareness-exercise seam.
- **Do not choose when:** Seeking deceptive sends or live email scanning. Compare
  authorization and awareness-program policy first.
- **Evidence limit:** One fixed email only; no mailbox, link, SMTP, employee
  targeting or detection guarantee.

## Run

```bash
npm ci
npm test
```

Expected output:

```text
TypeScript CY-04 phishing-awareness tutorial: all checks passed
```

No email is sent and no link is followed. Authorization and employee consent
belong to the consumer.
