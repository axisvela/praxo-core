# Python pollution tracing (CT-05)

A bounded first slice of [CT-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an environmental enforcement system. It compares fixed sensor and weather
records and drafts review-only investigation hypotheses. No live monitoring,
causal finding or enforcement action.

## Why this language and runtime?

- **Selection basis:** A Python environmental-data workflow can retain fixed evidence
  and add a review step in the same runtime. No monitoring consumer is verified.
- **Demonstrated fit:** Core callbacks return fixed sensor summaries and draft
  hypotheses; no sensor data is analyzed for causation.
- **Choose when:** Exploring the Core seam near existing Python environmental analysis.
- **Do not choose when:** Seeking pollution attribution or enforcement. Compare
  deterministic analysis, sensor validation and the existing regulatory process.
- **Evidence limit:** Core integration fixture only; no live monitoring, causal
  inference, inspection or enforcement finding.

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
