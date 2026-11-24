# Python Marketing Segments (CS-04)

Computes fixed consent-aware segments and drafts review-only content. No
publication or tracking.

## Why this language and runtime?

- **Selection basis:** Python often serves marketing analytics and content
  tooling; the review gate can stay beside that code.
- **Demonstrated fit:** A fixed audience yields three eligible customers, one
  consent exclusion and a draft-only content item for the top segment.
- **Choose when:** Adding a review-only content draft to a Python workflow.
- **Do not choose when:** Seeking automated publishing or tracking. Compare
  consent policy and the approval process first.
- **Evidence limit:** Four fixed audience rows only; no live CRM, segmentation
  model, publication or attribution claim.

## Run

```bash
PYTHONPATH=language/python python language/python/Tutorial/marketing-segments/app.py --test
```

Expected output:

```text
Python CS-04 marketing-segments tutorial: all checks passed
```

No CRM, publisher, tracking pixel or send is implemented. Consent, approval and
publication belong to the consumer.
