# Python biodiversity alerts (AE-05)

A bounded first slice of [AE-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an anti-poaching dispatch system. It classifies fixed labeled observations and
drafts a review-only ranger alert. No species-recognition guarantee, automatic
pursuit or live model.

From this directory:

```bash
python app.py --test
python app.py
python app.py --region region-200
python app.py --simulate-failure
```

Expected test output: `Python AE-05 biodiversity-alerts tutorial: all checks passed`.
Both negative commands exit nonzero.

`read_observations` returns 3 observations, 3 labels, 1 flagged and
`confidence=low` for `region-100`; `draft_ranger_review` returns two review items
with `status=draft_only`, `review_required=true`, `species_claims=0` and
`pursuits=0`. Policy limits the region and final `draft_review` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-region denial, and one read/zero drafts for the simulated observation-index
outage. Real sensor classification, species identification, pursuit and ranger
dispatch belong to the consumer.
