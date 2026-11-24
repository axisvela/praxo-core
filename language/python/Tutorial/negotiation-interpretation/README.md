# Python Negotiation Interpretation (OG-03)

Compares fixed transcript terms, flags uncertainty and drafts review-only notes.
No mind reading, micro-expression inference or live interpretation guarantee.

## Why this language and runtime?

- **Selection basis:** Python supports transcript and terminology analysis; the
  review step can stay beside existing tooling.
- **Demonstrated fit:** One fixed transcript yields two terms, one uncertain term
  and draft-only notes.
- **Choose when:** Evaluating a terminology-review seam beside human
  interpretation.
- **Do not choose when:** Seeking mind reading, intent inference or live
  interpretation. Compare professional interpretation and consent rules first.
- **Evidence limit:** One fixed transcript only; no audio, live speech, cultural
  model or intent inference.

## Run

```bash
PYTHONPATH=language/python python language/python/Tutorial/negotiation-interpretation/app.py --test
```

Expected output:

```text
Python OG-03 negotiation-interpretation tutorial: all checks passed
```

No live audio, mind reading, micro-expression inference or interpretation is
implemented. Consent, professional interpretation and review belong to the
consumer.
