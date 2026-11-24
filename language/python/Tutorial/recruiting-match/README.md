# Python recruiting match (OP-05)

A bounded first slice of [OP-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an automated hiring system. It matches fixed synthetic candidates against one
role and drafts a review-only shortlist. No outreach, identity checks or live model
are used.

## Why this language and runtime?

- **Selection basis:** Python is common in HR analytics and back-office automation,
  where candidate data and matching rules already live.
- **Demonstrated fit:** Native Python filters candidates by required skills and years,
  ranks them, and drafts a shortlist for human review.
- **Choose when:** Learning deterministic matching and review boundaries in an existing
  Python workflow.
- **Do not choose when:** Seeking hiring decisions, candidate outreach or compliance
  validation. Compare the HR platform's rules and review process first.
- **Evidence limit:** Fixed three-candidate fixture only; no identity checks, production
  ranking, fairness validation, outreach or hiring claim.

From this directory:

```bash
python app.py --test
python app.py
python app.py --role role-200
python app.py --simulate-failure
```

Expected test output: `Python OP-05 recruiting-match tutorial: all checks passed`.
Both negative commands exit nonzero.

`read_role` requires `go` and `sql` with at least four years and ranks `cand-3`
then `cand-1`; `draft_shortlist` returns `status=draft_only`,
`review_required=true` and `outreach_sent=0`. Policy limits the role and final
`shortlist` action.
