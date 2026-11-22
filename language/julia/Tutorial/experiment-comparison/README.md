# Julia Experiment Comparison Agent

A native Julia analytics tutorial. The Agent has one fixed tool,
`compare_experiments`, which computes means and a delta over fixed baseline and
candidate results. The deterministic model packages the computed values in a
report with an empty `mutating_actions` list. It does not read arbitrary data,
execute model-provided Julia code, install packages or modify the experiments.

## Run

From the repository root:

```bash
julia --project=language/julia language/julia/Tutorial/experiment-comparison/experiment_comparison.jl
```

Output:

```json
{"mutating_actions":[],"experiment":{"source":"fixture","samples":5,"delta":0.04400000000000004,"winner":"candidate","baseline_mean":0.74,"candidate_mean":0.784}}
```

The baseline results are `0.72, 0.75, 0.74, 0.73, 0.76`; the candidate results
are `0.78, 0.79, 0.77, 0.80, 0.78`. The Julia tool computes the metrics; the model
does not invent them.

## Failure Checks

```bash
julia --project=language/julia language/julia/Tutorial/experiment-comparison/experiment_comparison.jl --dataset other
julia --project=language/julia language/julia/Tutorial/experiment-comparison/experiment_comparison.jl --simulate-failure
julia --project=language/julia language/julia/Tutorial/experiment-comparison/experiment_comparison.jl --test
```

The first request is denied by Agent policy before the tool runs (`reads=0`).
The second simulates an unavailable experiment dependency after one read
(`reads=1`) and exits nonzero. The `--test` mode covers success, denial and
dependency failure and checks computed values rather than prose.

## Boundaries

- This uses the native Julia Core in source mode, not a remote Agent loop.
- The tool is fixed to one experiment fixture; no file path, arbitrary Julia
  code, package installation or shell command comes from the model.
- The report is teaching evidence, not a statistical significance test, causal
  claim, production experiment platform or benchmark.
- There is no live model, provider credential, dashboard, scheduler, durable
  report or independent consumer evidence.
- A successful local computation does not establish production monitoring or
  independent adoption.
