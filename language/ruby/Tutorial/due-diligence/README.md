# Ruby due diligence (LJ-03)

A bounded first slice of [LJ-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an acquisition opinion. It reconciles fixed ownership, contract and dispute
fixtures and drafts a review-only risk checklist. No verified deal conclusion,
data room or live model.

Run from the repository root:

```bash
ruby -I language/ruby/lib language/ruby/Tutorial/due-diligence/app.rb --test
ruby -I language/ruby/lib language/ruby/Tutorial/due-diligence/app.rb
ruby -I language/ruby/lib language/ruby/Tutorial/due-diligence/app.rb --target target-200
ruby -I language/ruby/lib language/ruby/Tutorial/due-diligence/app.rb --simulate-failure
```

Expected test output: `Ruby LJ-03 due-diligence tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_diligence` returns 2 ownership entities, 5 contracts, 1 dispute and a
`change_of_control` flag for `target-100`; `draft_checklist` returns three risks
with `status=draft_only`, `review_required=true`, `acquisition_conclusions=0` and
`deal_writes=0`. Policy limits the target and final `draft_risk_checklist`
action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-target denial, and one read/zero drafts for the simulated diligence-source
outage. Real legal review, valuation and acquisition decisions belong to the
consumer and counsel.
