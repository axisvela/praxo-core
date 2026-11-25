# Julia AI Scientific Computing Copilot (AI-native reference application)

A native Julia analysis copilot where the agent drives the numerical workflow:
load a fixed yield experiment, fit a quadratic response surface by ordinary least
squares, locate a bounded optimum, and return evidence-linked interpretation. The
script never publishes an experiment or changes the source data.

This is the AI-native Julia reference application. The existing
[`Tutorial/experiment-comparison`](../Tutorial/experiment-comparison/) tutorial
remains the basic deterministic comparison slice.

## Why this language and runtime?

- **Selection basis:** Julia is used for numerical analysis, optimization, and
  scientific applications that already keep data and models in one runtime.
- **Demonstrated fit:** A native `praxo-run` loop, a `LinearAlgebra` least-squares
  solve, an application-owned fixture, a policy callback, and an inspectable tool
  trace exercise the Core seam without a second analysis service.
- **Choose when:** Adding a governed analysis/review step to an existing Julia
  numerical workflow.
- **Do not choose when:** The task is a fixed report or a direct notebook
  calculation, or when a solver dependency and data contract are not available.
- **Evidence limit:** Fixture observations and a quadratic model. This is not a
  statistical validation, causal claim, production experiment platform, or
  solver certification.

## AI-native workflow

1. The operator asks for an analysis of the fixed `yield-fixture`.
2. The agent calls `load_observations` to read the app-owned data.
3. The agent calls `fit_response_surface`; Julia solves the least-squares system
   with `LinearAlgebra` and computes R², the bounded optimum, and predicted yield.
4. The model writes an interpretation; the application keeps the computed fields
   authoritative and writes `writes=0` and `mutating_actions=[]`.
5. `publish_experiment` is always denied. Any publication or lab-notebook write is
   outside the agent path.

If the model is removed, the primary analysis/review workflow disappears.

## Where is the LLM reasoning?

The deterministic tests use a scripted model. They verify the harness, policy,
numerical path, trace shape, and failure paths, not LLM reasoning.

A live path is implemented with `OpenAICompatibleModel`. A local hosted DeepSeek
`deepseek-flash` run on 2026-11-25 recorded `model=live`; the model chose
`load_observations` then `fit_response_surface`, and the final interpretation
reported the fitted model, R², bounded optimum, and predicted yield. The
application-owned report kept the computed values, `writes=0`, and
`mutating_actions=[]`.

On Windows the application transport adds `--ssl-no-revoke` to the local
`curl.exe`; the local run used `HTTPS_PROXY` and the workstation trust
configuration. This is transport plumbing, not model evidence.

## Host integration

| Boundary | Where |
| --- | --- |
| CLI entry | `application.jl` |
| Agent loop | `src/Agent.jl` (`praxo-run` equivalent) |
| Numerical fit | `fit_tool`, `LinearAlgebra` `\` |
| Model | `AnalysisModel` or `OpenAICompatibleModel` |
| Tools | `load_tool`, `fit_tool`, `publish_tool` |
| Policy | `AnalysisPolicy` |
| Trace | `TraceSink` |
| Tests | `--test` |

Identity, data access, experiment tracking, publication, and effect reconciliation
remain application-owned.

## Tools and policy

| Tool | Effect | Policy |
| --- | --- | --- |
| `load_observations` | Reads the fixed yield fixture | Tenant `lab-ops`; dataset `yield-fixture` |
| `fit_response_surface` | Fits a quadratic and computes a bounded optimum | Dataset `yield-fixture`; observations must be loaded first |
| `publish_experiment` | Would publish an experiment record | Always denied in the agent path |

A direct publish is denied before any effect. Another dataset is denied before
read. A fit before load returns a tool error. A tenant mismatch is denied before
the model. A simulated numerical dependency failure returns an error after the
read and leaves `writes=0`.

## Build and test

Julia 1.13+:

```bash
julia --project=language/julia language/julia/application/application.jl --test
```

Expected:

```text
Julia scientific copilot: all checks passed
```

The checks cover success, direct publication denial, other-dataset denial,
fit-before-load, tenant denial, and simulated dependency failure; they verify the
computed fit rather than fixed prose.

## Run

```bash
julia --project=language/julia language/julia/application/application.jl
```

Output is one JSON object with `fit`, `interpretation`, `agent`, and
`mutating_actions`. Direct publication and failure paths exit nonzero.

Live model:

```bash
export PRAXO_BASE_URL=https://api.deepseek.com
export PRAXO_MODEL=deepseek-flash
export PRAXO_API_KEY=...
julia --project=language/julia language/julia/application/application.jl --live
```

## Boundaries

- Fixture observations and a deterministic quadratic model; no experimental data
  store, statistics package, solver convergence proof, or uncertainty campaign.
- No dashboard, scheduler, lab-notebook write, publication, or account change.
- No production experiment system, durable report, identity provider, independent
  consumer, or production deployment.
- Local source runtime; not a registry-package install.
