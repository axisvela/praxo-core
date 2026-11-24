# PHP Recruiting Match (OP-05)

Matches fixed candidates against one role and drafts a review-only shortlist. No
outreach, ranking model or hiring decision.

## Why this language and runtime?

- **Selection basis:** PHP already runs many HR portals and internal tools; a
  review gate can stay beside that code.
- **Demonstrated fit:** A deterministic ranking and scoped tools produce two
  matched candidates and one draft-only shortlist.
- **Choose when:** Adding a governed shortlist review to an existing PHP tool.
- **Do not choose when:** Seeking automated hiring decisions or candidate
  outreach. Compare direct rules and the current review process first.
- **Evidence limit:** Three fixed candidates only; no live ATS, ranking quality,
  outreach or hiring effect.

## Run

```bash
php language/php/Tutorial/recruiting-match/app.php --test
```

Expected output:

```text
PHP OP-05 recruiting-match tutorial: success, denial and dependency failure passed
```

No ATS, outreach, ranking model or hiring decision is implemented. Candidate
identity, consent and review belong to the consumer.
