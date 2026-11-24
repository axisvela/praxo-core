# C++ mesh review (MD-05)

A bounded first slice of MD-05, not a CAD kernel or manufacturing-certification
flow. It compares fixed synthetic mesh descriptors against stated constraints and
drafts a review-only design assessment. No manufacturability certification or
fabrication.

Build and run from the repository root:

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build --target praxo-cpp-mesh-review-tutorial
./language/cpp/build/praxo-cpp-mesh-review-tutorial --test
./language/cpp/build/praxo-cpp-mesh-review-tutorial --mesh mesh-200
./language/cpp/build/praxo-cpp-mesh-review-tutorial --simulate-failure
```

Expected test output:

```text
success: mesh-100 faces=2400 checks=3 violations=0 status=draft_only certifications=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: MESH_UNAVAILABLE reads=1
```

`mesh-200` is denied by policy and exits `2`; `--simulate-failure` reads once,
reports `MESH_UNAVAILABLE`, and exits `1`.

`read_mesh` returns 1200 vertices, 2400 faces, 2.5 mm thickness against a 2.0 mm
minimum and 150 cm³ volume; `draft_design` returns three checks, zero violations,
`status=draft_only`, `review_required=true`, `certifications=0` and
`fabrications=0`. Policy limits the mesh and final `draft_review` action.

Real CAD geometry, topology repair, manufacturability analysis and mechanical
certification belong to the design team.
