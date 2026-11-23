# D Executive Brief (OP-07)

A bounded first slice of [OP-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an autonomous BI platform. It computes fixed business-line variances for one
period and drafts a review-only operating brief. This uses the source D Core with
`dmd -run`; no network, credentials or packages beyond DMD are required.

Run from the repository root:

```bash
dmd -i -Ilanguage/d/source -run language/d/Tutorial/executive-brief/brief.d --test
dmd -i -Ilanguage/d/source -run language/d/Tutorial/executive-brief/brief.d
dmd -i -Ilanguage/d/source -run language/d/Tutorial/executive-brief/brief.d --period period-200
dmd -i -Ilanguage/d/source -run language/d/Tutorial/executive-brief/brief.d --simulate-failure
```

Expected test output:

```text
success: period-100 revenue_delta=-4.2% status=draft_only sends=0 reads=1
deny: POLICY_ERROR reads=0
failure: METRICS_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

The deterministic model plans three steps and consumes each result: `read_metrics`
returns `revenue_delta=-4.2%`, `cost_delta=+1.5%` and `top_variance=supply_cost`;
`draft_brief` returns `status=draft_only`, `review_required=true` and `sends=0`.
Policy limits the period and final action; `requirePolicy` and `requireToolScope`
are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-period denial, and one read/zero drafts for the simulated metrics outage.

**Runtime note:** the D Core currently reports policy denial as `POLICY_ERROR`
(its conformance suite and examples assert this), not `AGENT_POLICY_DENIED`. This
tutorial documents the actual D behavior and does not claim cross-language error
code parity.

Real metric warehouses, attribution, distribution lists, approvals and effect
reconciliation belong to the consumer. No live provider, publication, independent
consumer or production reporting is claimed.
