# Fortran Pollution Tracing (CT-05)

Compares fixed sensor readings and drafts two investigation hypotheses. No causal
or enforcement finding.

## Why this language and runtime?

- **Selection basis:** Fortran fits fixed environmental numerics near existing
  analysis code.
- **Demonstrated fit:** Three fixed sensors yield a 48 µg/m³ peak and two
  hypotheses with no confidence claim.
- **Choose when:** Evaluating a review-only hypothesis seam.
- **Do not choose when:** Seeking source attribution or enforcement evidence.
  Compare dispersion modeling and regulatory procedure first.
- **Evidence limit:** Three fixed sensors only; no feed, model or finding. Local
  validation used `gfortran -fsyntax-only`; CI is configured and pending.

## Run

```bash
python language/fortran/Tutorial/pollution-tracing/run.py
```

Expected output:

```text
sensors=3
peak_sensor_index=1
peak_pm25= 48.0
hypotheses=2
confidence_claimed=F
status=draft_only
enforcement_findings=0
Fortran CT-05 pollution-tracing tutorial: passed (hypotheses only)
```

No enforcement finding or source confirmation is implemented. Regulatory review
belongs to the consumer.
