# Fortran simulation metrics review

A scoped numerical tutorial over the native MIT Fortran Core. It computes fixed
simulation metrics through a native tool, then lets a deterministic model package
the computed numbers into a review-only report. The metrics and model are
fixtures. This tutorial does not read arbitrary data, run model-provided Fortran,
install packages, publish a report or call a live model.

Build the pinned RE2 bridge once, then run the tutorial from the repository root:

```bash
python3 language/fortran/run-tests.py --re2-only
python language/fortran/Tutorial/simulation-metrics/run.py
```

Expected output:

```text
success: sim-100 mean=122.5 exceedances=2 status=draft_only writes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: SIMULATION_SOURCE_UNAVAILABLE reads=1
```

`sim-200` is denied by policy before the metric tool runs and exits non-zero. A
simulated source failure returns `SIMULATION_SOURCE_UNAVAILABLE` after one read.

## Path

1. `read_simulation` computes mean `122.5`, minimum `100.0`, maximum `145.0`,
   peak-to-peak `45.0`, threshold `135.0` and two exceedances over a fixed
   ten-sample series for `sim-100`.
2. `draft_summary` returns `status=draft_only`, `review_required=true` and
   `simulation_writes=0` for `publish_report`.
3. The deterministic model packages both tool results into a JSON report, so the
   model explains computed evidence instead of inventing it.

## Scope

This is source and local fixture evidence. It does not establish a real
simulation runtime, arbitrary dataset access, interpreted model code, a live
provider, public hosting or independent adoption. The tool and report fields are
tutorial-local and are not Core or wire API.
