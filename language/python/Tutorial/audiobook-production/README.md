# Python Audiobook Production (MD-06)

Plans fixed licensed voices and mixing cues and drafts a review-only plan. No
synthesis, rendering or rights guarantee.

## Why this language and runtime?

- **Selection basis:** Python is common in media pipelines; the planning review
  can stay beside existing tooling.
- **Demonstrated fit:** A fixed book yields three chapters, two licensed voices
  and four cues in a draft-only plan.
- **Choose when:** Evaluating a review-only production plan seam.
- **Do not choose when:** Seeking synthesis, rendering or rights clearance.
  Compare licensing and the production pipeline first.
- **Evidence limit:** One fixed book only; no TTS, renderer, rights database or
  audio output.

## Run

```bash
PYTHONPATH=language/python python language/python/Tutorial/audiobook-production/app.py --test
```

Expected output:

```text
Python MD-06 audiobook-production tutorial: all checks passed
```

No synthesis, rendering or audio file is implemented. Voice licensing, approval
and rendering belong to the consumer.
