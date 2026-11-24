# C++ ocean routing (TL-03)

A bounded first slice of TL-03, not a navigation or fuel-optimization system. It
compares fixed synthetic route/weather costs and drafts a review-only route. No
navigation command, fuel-savings claim or CII compliance guarantee.

Build and run from the repository root:

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build --target praxo-cpp-ocean-routing-tutorial
./language/cpp/build/praxo-cpp-ocean-routing-tutorial --test
./language/cpp/build/praxo-cpp-ocean-routing-tutorial --voyage voyage-200
./language/cpp/build/praxo-cpp-ocean-routing-tutorial --simulate-failure
```

Expected test output:

```text
success: voyage-100 routes=2 route=great-circle status=draft_only navigation=0 fuel_claims=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: VOYAGE_UNAVAILABLE reads=1
```

`voyage-200` is denied by policy and exits `2`; `--simulate-failure` reads once,
reports `VOYAGE_UNAVAILABLE`, and exits `1`.

`read_voyage` returns two routes (`great-circle` 100/12 days, `coastal` 115/14
days) with moderate weather for `voyage-100`; `draft_route` returns
`route=great-circle`, `status=draft_only`, `review_required=true`,
`navigation_commands=0` and `fuel_claims=0`. Policy limits the voyage and final
`draft_route` action.

Real weather routing, fuel models, navigation and regulatory reporting belong to
the operator.
