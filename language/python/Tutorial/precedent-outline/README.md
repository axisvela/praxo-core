# Python precedent outline (LJ-04)

A bounded first slice of [LJ-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not legal research or advice. It retrieves fixed synthetic precedents and drafts a
cited review-only outline. No live legal database, sentencing recommendation or
judicial decision.

From this directory:

```bash
python app.py --test
python app.py
python app.py --query query-200
python app.py --simulate-failure
```

Expected test output: `Python LJ-04 precedent-outline tutorial: all checks passed`.
Both negative commands exit nonzero.

`search_precedents` returns 3 precedents, 2 matches, citations `case-1`/`case-2`
and `mixed` jurisprudence for `query-100`; `draft_outline` returns two sections
with `status=draft_only`, `review_required=true`, `sentencing_recommendations=0`
and `judicial_decisions=0`. Policy limits the query and final `draft_outline`
action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-query denial, and one read/zero drafts for the simulated precedent-index
outage. Real legal research, citation validation and judicial analysis belong to
counsel.
