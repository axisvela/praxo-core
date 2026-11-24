# C++ molecule screen (SC-02)

A bounded first slice of SC-02, not drug discovery. It ranks fixed synthetic
molecular descriptors under stated constraints and drafts a review-only
assessment. No efficacy, toxicity, synthesis or clinical claim.

Build and run from the repository root:

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build --target praxo-cpp-molecule-screen-tutorial
./language/cpp/build/praxo-cpp-molecule-screen-tutorial --test
./language/cpp/build/praxo-cpp-molecule-screen-tutorial --target target-200
./language/cpp/build/praxo-cpp-molecule-screen-tutorial --simulate-failure
```

Expected test output:

```text
success: target-100 candidates=4 top=mol-2 status=draft_only efficacy=0 toxicity=0 syntheses=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: MOLECULE_UNAVAILABLE reads=1
```

`target-200` is denied by policy and exits `2`; `--simulate-failure` reads once,
reports `MOLECULE_UNAVAILABLE`, and exits `1`.

`read_candidates` returns 4 candidates with `mol-2` on top, `constraints_ok=true`
and illustrative descriptors (MW 342.1, logP 2.4) for `target-100`;
`draft_review` returns `status=draft_only`, `review_required=true`,
`efficacy_claims=0`, `toxicity_claims=0` and `syntheses=0`. Policy limits the
target and final `draft_review` action.

Real docking, ADMET prediction, synthesis planning and clinical evaluation belong
to the research team.
