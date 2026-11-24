# Fortran EDA Placement (OG-05)

Explores a fixed placement grid and reports stated proxy values. No foundry-valid
layout or proven PPA optimization.

## Why this language and runtime?

- **Selection basis:** Fortran fits fixed numerical placement proxies near
  existing EDA code.
- **Demonstrated fit:** A 4x4 grid with three placed cells and no overlaps yields
  a 12.5 wirelength proxy in a draft-only review.
- **Choose when:** Evaluating a review-only placement seam.
- **Do not choose when:** Seeking foundry validity or PPA guarantees. Compare the
  EDA flow and signoff checks first.
- **Evidence limit:** One fixed grid only; no router, timing model, foundry data
  or PPA proof. Local validation used `gfortran -fsyntax-only`; CI is configured
  and pending.

## Run

```bash
python language/fortran/Tutorial/eda-placement/run.py
```

Expected output:

```text
grid_size=4
placed=3
overlaps=0
within_grid=T
wirelength_proxy= 12.5
status=draft_only
foundry_valid=F
Fortran OG-05 eda-placement tutorial: passed (review only)
```

No foundry validation or PPA guarantee is implemented. Signoff approval belongs
to the consumer.
