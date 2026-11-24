# TypeScript negotiation interpretation (OG-03)

A bounded first slice of [OG-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an interpreter or cultural-profiling system. It compares a fixed bilingual
transcript excerpt and drafts review-only negotiation notes. No micro-expression
inference, mind reading or live interpretation guarantee.

## Why this language and runtime?

- **Selection basis:** A Node collaboration or meeting tool can add a review note
  beside its transcript handling. No meeting-platform consumer is verified.
- **Demonstrated fit:** Core tools return fixed transcript segments, terminology and
  a draft summary; no audio, translation or cultural inference runs.
- **Choose when:** Learning the tool/policy seam in an existing Node workflow.
- **Do not choose when:** Seeking live interpretation or cultural advice. Compare
  human interpreters, transcription services and the existing meeting process first.
- **Evidence limit:** Core integration fixture only; no audio capture, live
  interpretation, cultural judgment, mind reading or accuracy guarantee.

From this directory:

```bash
npm ci
npm test
node app.js
node app.js --session session-200
node app.js --simulate-failure
```

Expected test output: `TypeScript negotiation-interpretation tutorial: all checks passed`.
Both negative commands exit nonzero.

`read_transcript` returns 3 segments, one terminology note (`keigo`, honorific
register), `ambiguity=high` and `cues=0` for `session-100`; `draft_notes` returns
two notes with `status=draft_only`, `review_required=true`,
`mind_reading_claims=0` and `live_guarantee=false`. Policy limits the session and
final `draft_summary` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-session denial, and one read/zero drafts for the simulated transcript
outage. Real interpretation, cultural judgment and negotiation advice belong to
qualified humans.
