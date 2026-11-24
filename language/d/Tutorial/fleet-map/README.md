# D fleet map (TL-06)

A bounded first slice of TL-06, not a remote-assistance or map-deployment system.
It replays fixed synthetic road-topology changes and drafts a review-only map
patch. No vehicle takeover, automatic deployment or live fleet access.

Run from the repository root:

```bash
dmd -i -Ilanguage/d/source -run language/d/Tutorial/fleet-map/map_patch.d --test
dmd -i -Ilanguage/d/source -run language/d/Tutorial/fleet-map/map_patch.d
dmd -i -Ilanguage/d/source -run language/d/Tutorial/fleet-map/map_patch.d --fleet fleet-200
dmd -i -Ilanguage/d/source -run language/d/Tutorial/fleet-map/map_patch.d --simulate-failure
```

Expected test output:

```text
success: fleet-100 changes=2 confidence=medium status=draft_only takeovers=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: TOPOLOGY_UNAVAILABLE reads=1
```

`fleet-200` is denied by policy before the tool is called and exits nonzero.
`--simulate-failure` reads once, reports `TOPOLOGY_UNAVAILABLE`, and exits
nonzero.

`read_topology` returns 2 topology changes at medium confidence for `fleet-100`;
`draft_patch` returns `status=draft_only`, `review_required=true`,
`vehicle_takeovers=0` and `auto_deploys=0`. Policy limits the fleet and final
`draft_map_patch` action.

Real remote assistance, map validation, deployment and vehicle control belong to
the fleet operator.
