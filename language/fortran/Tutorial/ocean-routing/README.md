# Fortran Ocean Routing (TL-03)

Compares fixed route and weather costs and drafts a route. No navigation,
fuel-savings or CII compliance claim.

## Why this language and runtime?

- **Selection basis:** Fortran fits fixed route-cost optimization near existing
  numerical shipping code.
- **Demonstrated fit:** Two fixed routes compare 1300 versus 1130 and draft route
  two with no savings claim.
- **Choose when:** Evaluating a bounded route-review seam.
- **Do not choose when:** Seeking navigation or fuel guarantees. Compare routing
  systems and compliance rules first.
- **Evidence limit:** Two fixed routes only; no weather service, navigation or
  compliance. Local validation used `gfortran -fsyntax-only`; CI is configured
  and pending.

## Run

```bash
python language/fortran/Tutorial/ocean-routing/run.py
```

Expected output:

```text
route_1_cost=1300.0
route_2_cost=1130.0
selected_route=2
status=draft_only
fuel_savings_claim=F
navigation_commands=0
Fortran TL-03 ocean-routing tutorial: passed (draft route only)
```

No navigation command or savings claim is implemented. Master approval belongs
to the consumer.
