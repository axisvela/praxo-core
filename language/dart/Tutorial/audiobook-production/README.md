# Dart audiobook production (MD-06)

A bounded first slice of [MD-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an audio-production pipeline. It reads a fixed licensed book fixture and
drafts a review-only production plan with character and mixing cues. No
synthesized audio, voice cloning or rights guarantee.

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
