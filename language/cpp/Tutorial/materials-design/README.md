# C++ materials design (SC-04)

A bounded first slice of SC-04, not a validated materials-discovery pipeline. It
evaluates fixed synthetic candidate properties and drafts the next review-only
simulation. No validated new material or fabrication.

Build and run from the repository root:

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build --target praxo-cpp-materials-design-tutorial
./language/cpp/build/praxo-cpp-materials-design-tutorial --test
./language/cpp/build/praxo-cpp-materials-design-tutorial --batch batch-200
./language/cpp/build/praxo-cpp-materials-design-tutorial --simulate-failure
```

Expected test output:

```text
success: batch-100 candidates=3 best=mat-2 value=0.83 status=draft_only validated=0 fabrications=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: MATERIAL_UNAVAILABLE reads=1
```

`batch-200` is denied by policy and exits `2`; `--simulate-failure` reads once,
reports `MATERIAL_UNAVAILABLE`, and exits `1`.

`read_candidates` returns 3 candidates with `mat-2` best at 0.83 against a 0.85
target for `batch-100`; `draft_simulation` proposes `sim-2` at 1200 °C with
`status=draft_only`, `review_required=true`, `validated_materials=0` and
`fabrications=0`. Policy limits the batch and final `draft_simulation` action.

Real simulation, property validation and fabrication belong to the materials
research team.
