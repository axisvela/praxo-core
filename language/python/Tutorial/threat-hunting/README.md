# Python Threat Hunting (CY-03)

Searches fixed logs and drafts a cited synthetic TTP timeline. No external
intelligence or APT detection guarantee.

## Why this language and runtime?

- **Selection basis:** Python is common in detection engineering; a cited
  timeline can stay close to log analysis code.
- **Demonstrated fit:** Three fixed events yield two TTP matches and a draft-only
  timeline with event citations.
- **Choose when:** Evaluating a review-only timeline seam in a Python workflow.
- **Do not choose when:** Seeking APT attribution, live intelligence or detection
  guarantees. Compare detection data and analyst procedures first.
- **Evidence limit:** Three fixed events only; no live logs, threat feed,
  attribution or detection-quality claim.

## Run

```bash
PYTHONPATH=language/python python language/python/Tutorial/threat-hunting/app.py --test
```

Expected output:

```text
Python CY-03 threat-hunting tutorial: all checks passed
```

No live log ingestion, threat intelligence or attribution is implemented.
Detection ownership and analyst review belong to the consumer.
