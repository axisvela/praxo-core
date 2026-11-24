# R Pollution Tracing (CT-05)

Compares fixed sensor and wind records and drafts investigation hypotheses. No
causal or enforcement finding.

## Why this language and runtime?

- **Selection basis:** R is common in environmental analysis where computed
  evidence stays close to the records.
- **Demonstrated fit:** Native R ranks three fixed sensors and returns two
  hypotheses without a confidence claim.
- **Choose when:** Evaluating a review-only hypothesis seam in R analysis.
- **Do not choose when:** Seeking source attribution or enforcement evidence.
  Compare dispersion modeling and regulatory procedures first.
- **Evidence limit:** Three fixed sensors only; no live network, dispersion model
  or enforcement finding.

## Run

```bash
Rscript language/r/Tutorial/pollution-tracing/pollution_tracing.R --test
```

Expected output:

```text
R pollution-tracing tutorial: all checks passed
```

No enforcement finding, source confirmation or sensor write is implemented.
Regulatory review and data provenance belong to the consumer.
