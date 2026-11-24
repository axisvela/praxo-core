# R Executive Brief (OP-07)

Computes fixed metric deltas and cites them. No causal attribution or action.

## Why this language and runtime?

- **Selection basis:** R is common for period reporting where computed evidence
  must stay close to the data.
- **Demonstrated fit:** Native R computes revenue, margin and order deltas with
  metric citations and no causal claim.
- **Choose when:** Evaluating a brief boundary beside existing R reporting.
- **Do not choose when:** Seeking causal attribution or automated decisions.
  Compare the current analysis and review process first.
- **Evidence limit:** One fixed period only; no warehouse, causal model or
  business effect.

## Run

```bash
Rscript language/r/Tutorial/executive-brief/executive_brief.R --test
```

Expected output:

```text
R executive-brief tutorial: all checks passed
```

No data warehouse, causal inference or action is implemented. Metric ownership
and review belong to the consumer.
