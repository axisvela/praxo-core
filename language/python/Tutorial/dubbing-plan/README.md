# Python dubbing plan (MD-04)

A bounded first slice of [MD-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a dubbing or voice-cloning product. It reads fixed licensed media segments and
drafts a review-only caption and timing plan. No audio synthesis, impersonation,
unconsented voice cloning or verified lip-sync.

From this directory:

```bash
python app.py --test
python app.py
python app.py --media media-200
python app.py --simulate-failure
```

Expected test output: `Python MD-04 dubbing-plan tutorial: all checks passed`.
Both negative commands exit nonzero.

`read_media` returns 4 segments, target language `ja`, `licensed` consent and a
0.8 s caption limit for `media-100`; `draft_caption_plan` returns 4 captions with
`status=draft_only`, `review_required=true`, `voice_clones=0` and
`lip_sync_claims=0`. Policy limits the media and final `draft_caption_plan`
action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-media denial, and one read/zero drafts for the simulated media-index
outage. Real audio production, rights clearance, voice consent and lip-sync
verification belong to the consumer.
