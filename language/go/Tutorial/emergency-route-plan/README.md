# Go emergency route plan

A scoped emergency-planning tutorial over the Go reference Core. It reads fixed
road closures for one event through an application-owned `RoadSource`, drafts a
review-only relief allocation and records zero dispatches. The source and model
are deterministic fixtures. This tutorial does not direct rescue operations,
dispatch vehicles, call a live model or guarantee route safety.

## Why this language and runtime?

- **Selection basis:** Go services and command tooling can ship an incident-planning
  boundary as a small binary. No emergency-management consumer is verified.
- **Demonstrated fit:** Fixed closures and constraints produce a review-only route
  allocation; no dispatch, traffic feed or rescue direction runs.
- **Choose when:** Learning a bounded planning draft in an existing Go service.
- **Do not choose when:** Seeking operational dispatch or route safety. Compare
  existing command systems and deterministic routing rules first.
- **Evidence limit:** Core integration fixture only; no live closures, optimization
  quality, dispatch or rescue guarantee.

Run from the repository root:

```bash
go run ./language/go/Tutorial/emergency-route-plan --test
go run ./language/go/Tutorial/emergency-route-plan --event event-200
go run ./language/go/Tutorial/emergency-route-plan --simulate-failure
```

Expected test output:

```text
success: event-100 closures=2 routes=2 status=draft_only dispatches=0 reads=1
deny: policy denied reads=0
failure: ROAD_INDEX_UNAVAILABLE reads=1
```

`event-200` is denied by policy before the source is called and exits `1`.
`--simulate-failure` reads once, reports `ROAD_INDEX_UNAVAILABLE`, and exits `1`.
The package also has a Go test (`go test ./language/go/Tutorial/emergency-route-plan`).

`read_event` returns `road-1` closed and `road-2` open with 2 depots and 1
shelter; `draft_allocation` returns 2 constrained routes with
`status=draft_only`, `review_required=true`, `dispatches=0` and
`rescue_orders=0`. Policy limits the event and final `draft_allocation` action.

Real incident command, live traffic data, operational dispatch and rescue
direction belong to the consumer.
