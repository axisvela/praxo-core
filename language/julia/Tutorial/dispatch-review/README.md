# Julia Dispatch Review (IN-04)

A bounded energy-dispatch planning tutorial. It enumerates a small two-source
integer dispatch, calculates cost and unmet demand, and lets Core choose a
plan-review or shortfall-review branch. No grid command is issued.

## Why this language and runtime?

- **Selection basis:** Julia is used for numerical optimization and scientific
  planning, where optimization models already sit beside analysis code.
- **Demonstrated fit:** The tutorial computes an actual bounded optimum (`60/40`,
  cost `3800`) and a real shortfall (`10` unmet) by changing input; it is not a
  prewritten answer. The current implementation uses native enumeration, not JuMP.
- **Choose when:** An existing Julia planning workflow needs a governed review seam.
- **Do not choose when:** A production solver, unit commitment or grid control is
  required. Use JuMP/domain solvers and validate feasibility before any dispatch.
- **Evidence limit:** Two sources, integer capacities and fixture costs only; no JuMP
  dependency, unit commitment, network constraints, grid command or savings claim.

## Run

From the repository root:

```bash
julia --project=language/julia language/julia/Tutorial/dispatch-review/dispatch_review.jl --test
julia --project=language/julia language/julia/Tutorial/dispatch-review/dispatch_review.jl
julia --project=language/julia language/julia/Tutorial/dispatch-review/dispatch_review.jl --shortfall
julia --project=language/julia language/julia/Tutorial/dispatch-review/dispatch_review.jl --deny
julia --project=language/julia language/julia/Tutorial/dispatch-review/dispatch_review.jl --simulate-failure
```

Expected test output:

```text
Julia dispatch-review tutorial: optimization, branches, denial and failure passed
```

Demand 100 with capacities 60/60 produces 60+40 at cost 3800 and
`review_plan`. Demand 130 produces 10 unmet and `review_shortfall`.
`--deny` and `--simulate-failure` exit nonzero.
