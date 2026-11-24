# Fortran Weather Anomaly (SC-05)

Computes fixed temperature anomalies and drafts a review-only notice. No
operational forecast or warning dispatch.

## Why this language and runtime?

- **Selection basis:** Fortran remains common in numerical weather code; the
  review step can stay beside fixed computations.
- **Demonstrated fit:** Seven fixed samples yield mean 17.1, peak 25.0, two
  exceedances and a draft-only notice.
- **Choose when:** Evaluating a review seam around existing Fortran numerics.
- **Do not choose when:** Seeking forecasts or public warnings. Compare the
  operational model and warning authority first.
- **Evidence limit:** Seven fixed samples only; no model, observation feed,
  forecast or dispatch. Local validation used `gfortran -fsyntax-only`; CI is
  configured and pending.

## Run

```bash
python language/fortran/Tutorial/weather-anomaly/run.py
```

Expected output:

```text
mean= 17.1
max= 25.0
exceedances=2
status=draft_only
warnings_sent=0
Fortran SC-05 weather-anomaly tutorial: passed (review notice only)
```

No forecast model or warning dispatch is implemented. Authority and review
belong to the consumer.
