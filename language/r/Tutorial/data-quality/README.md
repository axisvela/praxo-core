# R Data Quality Agent

A native R analytics tutorial. The Agent has one fixed tool,
`summarize_dataset`, which computes statistics over a synthetic data frame. The
deterministic model returns the computed values as a structured report instead
of inventing numbers. It does not read arbitrary files, run SQL, execute shell
commands or change the dataset.

## Run

From the repository root:

```bash
Rscript language/r/Tutorial/data-quality/data_quality.R
```

Output:

```json
{"data_quality":{"source":"fixture","rows":6,"missing_amount":1,"complete_rows":5,"mean_amount":118,"max_score":0.95,"regions":4},"mutating_actions":[]}
```

The data frame is fixed in the tutorial: six rows, four regions, one missing
amount and one score outlier. The R tool computes the counts and summary values;
the model only packages the tool result.

## Failure Checks

```bash
Rscript language/r/Tutorial/data-quality/data_quality.R --dataset other
Rscript language/r/Tutorial/data-quality/data_quality.R --simulate-failure
Rscript language/r/Tutorial/data-quality/data_quality.R --test
```

The first request is denied by Agent policy before the tool runs (`reads=0`).
The second simulates an unavailable data dependency after one read attempt
(`reads=1`) and exits nonzero. The `--test` mode covers success, denial and
dependency failure, and checks the computed values rather than trusting prose.

## Boundaries

- This uses the native R Core in source mode, not a remote Agent loop.
- The tool is fixed to one synthetic data frame; no file path, SQL query, shell
  or package installation comes from the model.
- The result is a teaching report, not a validated statistical analysis,
  production data pipeline or causal claim.
- There is no live model, provider credential, dashboard, scheduler, durable
  report or independent consumer evidence.
- A successful local computation does not establish production monitoring or
  independent adoption.
