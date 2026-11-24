# Python Literature Review (SC-01)

Retrieves two fixed abstracts and drafts unverified hypotheses with citations. No
fabricated papers or verified conclusions.

## Why this language and runtime?

- **Selection basis:** Python is common in research tooling where citations must
  remain separate from conclusions.
- **Demonstrated fit:** Fixed abstracts yield cited findings and a draft marked
  unverified.
- **Choose when:** Evaluating a review-only synthesis seam in a Python workflow.
- **Do not choose when:** Seeking a systematic review, meta-analysis or verified
  claim. Compare the review protocol and source licensing first.
- **Evidence limit:** Two fixed abstracts only; no literature database, screening,
  statistical synthesis or fabrication detection guarantee.

## Run

```bash
PYTHONPATH=language/python python language/python/Tutorial/literature-review/app.py --test
```

Expected output:

```text
Python SC-01 literature-review tutorial: all checks passed
```

No database search, PDF ingestion, systematic review or verified hypothesis is
implemented. Protocol, screening and citation checking belong to the consumer.
