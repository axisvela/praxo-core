# Dart audiobook production (MD-06)

A bounded first slice of [MD-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an audio-production pipeline. It reads a fixed licensed book fixture and
drafts a review-only production plan with character and mixing cues. No
synthesized audio, voice cloning or rights guarantee.

## Why this language and runtime?

- **Selection basis:** A Dart or Flutter media app could keep production planning in
  the same client/application runtime. No audio product is verified here.
- **Demonstrated fit:** Fixed book metadata produces a review-only production plan;
  no audio synthesis, TTS or mixing pipeline runs.
- **Choose when:** Learning the Core seam in an existing Dart media workflow.
- **Do not choose when:** Seeking audio generation or rights clearance. Compare audio
  engines, licensed voice pipelines and the existing rights process first.
- **Evidence limit:** Core integration fixture only; no synthesized audio, voice
  cloning, mixing, rights guarantee or media export.

Run from the repository root:

```bash
dart language/dart/Tutorial/audiobook-production/audiobook.dart --test
dart language/dart/Tutorial/audiobook-production/audiobook.dart
dart language/dart/Tutorial/audiobook-production/audiobook.dart --book book-200
dart language/dart/Tutorial/audiobook-production/audiobook.dart --simulate-failure
```

Expected test output: `Dart MD-06 audiobook-production tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_book` returns 12 chapters, 3 characters, 8 cues and `licensed=true` for
`book-100`; `draft_production` returns 12 segments with `status=draft_only`,
`review_required=true`, `synthesized_audio=false` and `rights_claims=0`. Policy
limits the book and final `draft_production` action.

Tests assert one read and one draft on success, zero reads/drafts for a cross-book
denial, and one read/zero drafts for the simulated book-index outage. Real
recording, synthesis, mixing and rights clearance belong to the consumer.
