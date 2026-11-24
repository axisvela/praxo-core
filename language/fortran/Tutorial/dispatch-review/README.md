# Fortran Dispatch Review (IN-04)

Simulates a fixed charge/discharge schedule and checks limits outside the agent.
No grid command.

## Why this language and runtime?

- **Selection basis:** Fortran fits deterministic numerical dispatch checks near
  existing energy code.
- **Demonstrated fit:** A fixed schedule yields 35 MW shortfall, level 65 within
  limits and a draft-only review.
- **Choose when:** Evaluating a bounded dispatch-review seam.
- **Do not choose when:** Seeking grid control or market dispatch. Compare the
  grid operator rules and simulation model first.
- **Evidence limit:** Fixed values only; no grid, battery, market or dispatch
  effect. Local validation used `gfortran -fsyntax-only`; CI is configured and
  pending.

## Run

```bash
python language/fortran/Tutorial/dispatch-review/run.py
```

Expected output:

```text
shortfall_mw=35
within_limits=T
level= 65.0
status=draft_only
grid_commands=0
Fortran IN-04 dispatch-review tutorial: passed (simulation only, no grid commands)
```

No grid command or dispatch is implemented. Operator approval belongs to the
consumer.
