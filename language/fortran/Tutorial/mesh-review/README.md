# Fortran Mesh Review (MD-05)

Compares a fixed mesh descriptor against stated constraints and drafts an
assessment. No manufacturability or mechanical certification.

## Why this language and runtime?

- **Selection basis:** Fortran fits fixed topology and numerical checks near
  existing engineering code.
- **Demonstrated fit:** Three nodes, two triangles and zero overlaps remain within
  constraints in a draft-only review.
- **Choose when:** Evaluating a bounded mesh-review seam.
- **Do not choose when:** Seeking certification or manufacturability proof.
  Compare CAD/CAE validation and engineering review first.
- **Evidence limit:** One fixed mesh only; no geometry kernel, solver or
  certification. Local validation used `gfortran -fsyntax-only`; CI is configured
  and pending.

## Run

```bash
python language/fortran/Tutorial/mesh-review/run.py
```

Expected output:

```text
nodes=3
triangles=2
overlaps=0
within_constraints=T
surface_area_proxy= 12.5
status=draft_only
manufacturing_certified=F
Fortran MD-05 mesh-review tutorial: passed (review only)
```

No manufacturing certification is implemented. Engineering approval belongs to
the consumer.
