# Fortran Fire Spread (AE-02)

Replays fixed fuel/weather cells and reports a modeled spread. No operational
warning or firebreak dispatch.

## Why this language and runtime?

- **Selection basis:** Fortran fits fixed-grid spread numerics near existing
  environmental code.
- **Demonstrated fit:** Three fixed cells yield one high-risk cell and a modeled
  spread of two with no operational warning.
- **Choose when:** Evaluating a review-only spread seam.
- **Do not choose when:** Seeking operational warnings or firebreak dispatch.
  Compare the fire-management system and authority first.
- **Evidence limit:** Three fixed cells only; no live weather, operational model
  or dispatch. Local validation used `gfortran -fsyntax-only`; CI is configured
  and pending.

## Run

```bash
python language/fortran/Tutorial/fire-spread/run.py
```

Expected output:

```text
cells=3
high_risk_cells=1
modeled_spread=2
status=draft_only
operational_warning=F
firebreak_dispatch=0
Fortran AE-02 fire-spread tutorial: passed (modeled spread only)
```

No warning or firebreak dispatch is implemented. Emergency authority belongs to
the consumer.
