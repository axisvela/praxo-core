# Python biodiversity alerts (AE-05)

A bounded first slice of [AE-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an anti-poaching dispatch system. It classifies fixed labeled observations and
drafts a review-only ranger alert. No species-recognition guarantee, automatic
pursuit or live model.

## Why this language and runtime?

- **Selection basis:** A Python conservation workflow can keep a review queue in its
  existing runtime. No ranger or sensor-network consumer is verified.
- **Demonstrated fit:** Core tools return fixed labeled observations and draft a ranger
  review; no image or audio classifier runs.
- **Choose when:** Learning the Core seam in an existing Python conservation workflow.
- **Do not choose when:** Seeking species recognition or pursuit decisions. Compare
  existing computer-vision models and ranger procedures first.
- **Evidence limit:** Core integration fixture only; no sensor feed, species
  identification, confidence calibration, pursuit or dispatch.

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
