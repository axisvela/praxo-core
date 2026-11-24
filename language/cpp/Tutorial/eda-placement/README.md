# C++ EDA placement (OG-05)

A bounded first slice of OG-05, not a foundry-valid physical-design flow. It reads
a fixed synthetic placement grid and drafts a review-only placement with stated
PPA proxies. No routing sign-off, foundry validation or tapeout.

## Why this language and runtime?

- **Selection basis:** EDA flows are native C++ workloads; keeping a review seam beside
  the placement code avoids moving design data into a service.
- **Demonstrated fit:** Fixed grid and proxy values produce a review-only placement;
  no placer, router, DRC/LVS or foundry rule deck runs.
- **Choose when:** Evaluating the Core seam in an existing C++ EDA tool.
- **Do not choose when:** Seeking PPA optimization or sign-off. Compare established EDA
  engines and the real process design kit first.
- **Evidence limit:** Core integration fixture only; proxies are illustrative, with no
  measured PPA, foundry validity, DRC/LVS or tapeout.

Build and run from the repository root:

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build --target praxo-cpp-eda-placement-tutorial
./language/cpp/build/praxo-cpp-eda-placement-tutorial --test
./language/cpp/build/praxo-cpp-eda-placement-tutorial --grid grid-200
./language/cpp/build/praxo-cpp-eda-placement-tutorial --simulate-failure
```

Expected test output:

```text
success: grid-100 cells=64 placements=64 status=draft_only foundry_valid=false tapeouts=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: GRID_UNAVAILABLE reads=1
```

`grid-200` is denied by policy and exits `2`; `--simulate-failure` reads once,
reports `GRID_UNAVAILABLE`, and exits `1`.

`read_grid` returns 64 cells, 40 nets, power proxy 12.5 and area proxy 0.82;
`draft_layout` returns 64 placements with `status=draft_only`,
`review_required=true`, `foundry_valid=false` and `tapeouts=0`. Policy limits the
grid and final `draft_placement` action.

The proxies are demonstration values, not measured PPA. Real DRC/LVS, timing,
routing and foundry sign-off belong to the physical-design team.
