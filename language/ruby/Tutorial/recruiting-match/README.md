# Ruby Recruiting Match (OP-05)

A bounded first slice of [OP-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an automated hiring system. It matches fixed synthetic candidates against one
role and drafts a review-only shortlist. No outreach, identity checks or live model
are used.

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
