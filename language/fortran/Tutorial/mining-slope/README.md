# Fortran Mining Slope (BE-03)

Computes fixed displacement indicators and drafts a review alert. No collapse
prediction or vehicle dispatch.

## Why this language and runtime?

- **Selection basis:** Fortran fits fixed geotechnical numerics near existing
  monitoring code.
- **Demonstrated fit:** Three fixed stations yield one flag above 5 mm, a 7 mm
  peak and a draft-only alert.
- **Choose when:** Evaluating a review-alert seam.
- **Do not choose when:** Seeking collapse prediction or vehicle control. Compare
  geotechnical monitoring and mine safety procedures first.
- **Evidence limit:** Three fixed stations only; no sensor feed, prediction or
  dispatch. Local validation used `gfortran -fsyntax-only`; CI is configured and
  pending.

## Run

```bash
python language/fortran/Tutorial/mining-slope/run.py
```

Expected output:

```text
stations=3
flagged=1
max_displacement_mm= 7.0
status=draft_only
collapse_prediction=F
vehicle_dispatches=0
Fortran BE-03 mining-slope tutorial: passed (review alert only)
```

No collapse prediction or vehicle dispatch is implemented. Site authority belongs
to the consumer.
