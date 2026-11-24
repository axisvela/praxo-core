# Fortran Leak Localization (CT-02)

Ranks fixed pressure drops and drafts a review-only inspection. No valve
isolation or field dispatch.

## Why this language and runtime?

- **Selection basis:** Fortran fits fixed pressure-series analysis beside utility
  numerical code.
- **Demonstrated fit:** Four fixed pressures yield two anomalies, a 38 kPa peak
  drop and a draft-only inspection.
- **Choose when:** Evaluating a bounded inspection seam.
- **Do not choose when:** Seeking leak proof or valve control. Compare hydraulic
  analysis and field procedures first.
- **Evidence limit:** Fixed series only; no SCADA, hydraulic model, isolation or
  dispatch. Local validation used `gfortran -fsyntax-only`; CI is configured and
  pending.

## Run

```bash
python language/fortran/Tutorial/leak-localization/run.py
```

Expected output:

```text
anomalies=2
max_drop_kpa= 38.0
ranked_valves=valve-12,valve-7
status=draft_only
isolations=0
Fortran CT-02 leak-localization tutorial: passed (inspection only, no isolation)
```

No valve isolation or dispatch is implemented. Network approval belongs to the
consumer.
