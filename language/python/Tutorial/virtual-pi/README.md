# Python virtual PI (OG-07)

A bounded first slice of [OG-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an autonomous research team. It coordinates three fixed
literature/simulation/review tasks within one shared budget and drafts a
review-only plan with provenance. No external tools, scientific-validity claim or
live model.

## Why this language and runtime?

- **Selection basis:** Research code is often Python, so a shared coordination and
  review boundary can live near existing analysis scripts.
- **Demonstrated fit:** Core tools return fixed task metadata and a draft coordination
  plan; no literature or simulation tool is invoked.
- **Choose when:** Learning the shared-limit and provenance pattern in Python.
- **Do not choose when:** Seeking multi-agent orchestration or research validity.
  Compare workflow engines and direct analysis pipelines first.
- **Evidence limit:** Core integration fixture only; no external tools, shared state,
  scientific validation or autonomous research claim.

From this directory:

```bash
python app.py --test
python app.py
python app.py --project project-200
python app.py --simulate-failure
```

Expected test output: `Python OG-07 virtual-pi tutorial: all checks passed`.
Both negative commands exit nonzero.

`read_tasks` returns 3 tasks, a 60-minute shared budget and provenance
`paper-1`/`sim-1` for `project-100`; `draft_plan` returns three stages with
`status=draft_only`, `review_required=true`, `validity_claims=0` and
`external_calls=0`. Policy limits the project and final `draft_coordination`
action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-project denial, and one read/zero drafts for the simulated project-index
outage. Real literature search, simulation and scientific review belong to the
research team.
