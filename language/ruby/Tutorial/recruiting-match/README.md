# Ruby Recruiting Match (OP-05)

A bounded first slice of [OP-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an automated hiring system. It matches fixed synthetic candidates against one
role and drafts a review-only shortlist. No outreach, identity checks or live model
are used.

## Why this language and runtime?

- **Selection basis:** An existing Ruby HR or back-office application can embed the
  review workflow without adding a separate Agent service.
- **Demonstrated fit:** Native Ruby filters and ranks a tiny synthetic candidate set
  by required skills and years; the draft is review-only.
- **Choose when:** Learning the Core seam in an already maintained Ruby application.
- **Do not choose when:** Seeking hiring decisions or candidate outreach. Compare
  direct deterministic matching and the existing HR workflow first.
- **Evidence limit:** Core integration with a fixed three-candidate fixture; no
  identity checks, production ranking, outreach, fairness validation or hiring claim.

Run from the repository root:

```bash
ruby -I language/ruby/lib language/ruby/Tutorial/recruiting-match/app.rb --test
ruby -I language/ruby/lib language/ruby/Tutorial/recruiting-match/app.rb
ruby -I language/ruby/lib language/ruby/Tutorial/recruiting-match/app.rb --role role-200
ruby -I language/ruby/lib language/ruby/Tutorial/recruiting-match/app.rb --simulate-failure
```

Expected test output: `Ruby OP-05 recruiting-match tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_role` requires `go` and `sql` with at least four years and ranks `cand-3`
then `cand-1`; `draft_shortlist` returns `status=draft_only`,
`review_required=true` and `outreach_sent=0`. Policy limits the role and final
`shortlist` action. Tests assert one read and one draft on success, zero
reads/drafts for a cross-role denial, and one read/zero drafts for the simulated
candidate-source outage.

Real candidate data, consent, skills validation, outreach and hiring decisions
belong to the consumer. No live provider, publication, independent consumer or
production recruiting decision is claimed.
