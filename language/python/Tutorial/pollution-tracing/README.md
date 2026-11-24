# Python pollution tracing (CT-05)

A bounded first slice of [CT-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an environmental enforcement system. It compares fixed sensor and weather
records and drafts review-only investigation hypotheses. No live monitoring,
causal finding or enforcement action.

From this directory:

```bash
python app.py --test
python app.py
python app.py --region region-200
python app.py --simulate-failure
```

Expected test output: `Python CT-05 pollution-tracing tutorial: all checks passed`.
Both negative commands exit nonzero.

`read_sensors` returns 3 sensors, 2 exceedances, north wind and candidate source
`plant-3` for `region-100`; `draft_hypotheses` returns two hypotheses with
`status=draft_only`, `review_required=true` and `enforcement_findings=0`. Policy
limits the region and final `draft_investigation` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-region denial, and one read/zero drafts for the simulated sensor-index
outage. Real monitoring, causal attribution, inspection and enforcement belong to
the consumer.
