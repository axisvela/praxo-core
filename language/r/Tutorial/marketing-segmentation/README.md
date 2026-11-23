# R marketing segmentation

A native R Core tutorial for campaign segmentation. It computes per-segment
statistics over a fixed customer fixture, identifies the highest-value segment,
and drafts a review-only invite for that segment. The model packages computed
evidence rather than inventing segments. This tutorial does not send messages,
launch a campaign, read arbitrary data, install packages or call a live model.

Run from the repository root:

```bash
Rscript language/r/Tutorial/marketing-segmentation/marketing.R --test
Rscript language/r/Tutorial/marketing-segmentation/marketing.R
Rscript language/r/Tutorial/marketing-segmentation/marketing.R --dataset other
Rscript language/r/Tutorial/marketing-segmentation/marketing.R --simulate-failure
```

Expected test output:

```text
R marketing-segmentation tutorial: all checks passed
```

`--dataset other` is denied by policy before the segment tool runs (reads=0) and
exits non-zero. `--simulate-failure` reads once, reports the failure and exits
non-zero.

## Path

1. `segment_customers` splits eight fixed customers into four segments and returns
   per-segment counts and average spend (`vip` averages `825`), plus `consented=6`.
2. `draft_campaign` returns `status=draft_only`, `review_required=true` and
   `messages_sent=0` for `invite_segment` on the top segment.
3. The deterministic model packages both tool results into a JSON report with an
   empty `mutating_actions` list.

The application owns consent enforcement, sending, suppression lists and effect
reconciliation.

## Scope

This is source and local fixture evidence. It does not establish a real customer
dataset, a live campaign, delivery, a live provider, public hosting or independent
adoption. The tools and report fields are tutorial-local and are not Core or wire
API.
