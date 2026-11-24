# Python Litigation Timeline (LJ-01)

Builds a cited timeline from fixed documents and drafts a review-only examination
outline. No legal advice or admissibility claim.

## Why this language and runtime?

- **Selection basis:** Python fits document review tooling where citations must
  stay attached to facts.
- **Demonstrated fit:** Three fixed documents yield a dated timeline, one
  contradiction and a draft-only outline.
- **Choose when:** Evaluating a cited timeline seam before attorney review.
- **Do not choose when:** Seeking legal advice or admissibility conclusions.
  Compare privilege, evidence rules and attorney procedures first.
- **Evidence limit:** Three synthetic documents only; no discovery platform,
  privilege check or admissibility analysis.

## Run

```bash
PYTHONPATH=language/python python language/python/Tutorial/litigation-timeline/app.py --test
```

Expected output:

```text
Python LJ-01 litigation-timeline tutorial: all checks passed
```

No legal advice, filing, admissibility finding or evidence authentication is
implemented. Privilege and attorney review belong to the consumer.
