# Haskell policy simulation (OG-02)

A bounded first slice of OG-02, not a policy-prediction engine. It simulates a
small fixed synthetic population and drafts a review-only sensitivity report
using the source Haskell Core through `runghc`. No tens-of-thousands scale,
external simulator or real policy prediction.

Run from the repository root:

```bash
runghc -ilanguage/haskell/src language/haskell/Tutorial/policy-simulation/app.hs --test
runghc -ilanguage/haskell/src language/haskell/Tutorial/policy-simulation/app.hs
runghc -ilanguage/haskell/src language/haskell/Tutorial/policy-simulation/app.hs --scenario scenario-200
runghc -ilanguage/haskell/src language/haskell/Tutorial/policy-simulation/app.hs --simulate-failure
```

Expected test output:

```text
success: scenario-100 households=12 agents=30 status=draft_only predictions=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: POPULATION_INDEX_UNAVAILABLE reads=1
```

`scenario-200` is denied by policy before the tool runs. `--simulate-failure`
reads once, reports `POPULATION_INDEX_UNAVAILABLE`, and exits nonzero.

`read_population` returns 12 households, 30 agents and the `subsidy` policy for
`scenario-100`; `draft_report` returns 3 runs, two sensitivity factors,
`status=draft_only`, `review_required=true`, `policy_predictions=0` and
`scale_claims=0`. Policy limits the scenario and final `draft_simulation` action.

Real population data, calibrated simulation and policy analysis belong to the
research team.
