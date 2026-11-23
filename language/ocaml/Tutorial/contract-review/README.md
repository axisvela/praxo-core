# OCaml Contract Review (FC-05)

A bounded first slice of [FC-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not legal advice or an e-signature system. It compares fixed contract clauses to a
redline set and drafts review-only redlines. No document store or live model.

Run from **this directory** (the `#use` path is relative to the working directory):

```bash
cd language/ocaml/Tutorial/contract-review
ocaml unix.cma review.ml --test
ocaml unix.cma review.ml
ocaml unix.cma review.ml --contract contract-200
ocaml unix.cma review.ml --simulate-failure
```

Expected test output:

```text
success: contract-100 findings=2 high=liability_cap_missing status=draft_only edits=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: CLAUSE_SOURCE_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

`read_clauses` returns three fixed clauses and two findings (high
`liability_cap_missing`, medium `payment_terms_extended`); `draft_revision`
returns `status=draft_only`, `review_required=true` and `edits_applied=0`. The
action policy limits the contract and final `propose_redline` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-contract denial, and one read/zero drafts for the simulated clause-source
outage. Real contracts, clause extraction, legal review and negotiation belong to
the consumer.
