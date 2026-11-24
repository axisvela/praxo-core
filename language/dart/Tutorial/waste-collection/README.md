# Dart waste collection (CT-06)

A bounded first slice of [CT-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a fleet-dispatch system. It reads a fixed collection queue and drafts a
review-only schedule under vehicle limits. No vehicle commands, live telemetry or
live model.

## Why this language and runtime?

- **Selection basis:** An existing Dart or Flutter municipal application could
  retain client-side orchestration. No such consumer is verified here.
- **Demonstrated fit:** A Dart CLI uses Core tools and policy checks over a fixed
  queue; assigned stops and `capacity_ok` are preselected values.
- **Choose when:** Learning the Core seam before adding it to a Dart host.
- **Do not choose when:** Seeking a route optimizer or Flutter integration. Compare
  established routing solvers or an existing backend service first.
- **Evidence limit:** Core integration fixture only; no solver, Flutter entry,
  telemetry, vehicle dispatch or capacity guarantee.

Run from the repository root:

```bash
dart language/dart/Tutorial/waste-collection/waste.dart --test
dart language/dart/Tutorial/waste-collection/waste.dart
dart language/dart/Tutorial/waste-collection/waste.dart --route route-200
dart language/dart/Tutorial/waste-collection/waste.dart --simulate-failure
```

Expected test output: `Dart CT-06 waste-collection tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_route` returns 12 fixed stops, 2 vehicles and `capacity_ok=true` for
`route-100`; `draft_schedule` returns `assigned_stops=12` with
`status=draft_only`, `review_required=true` and `vehicle_commands=0`. Policy
limits the route and final `draft_route` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-route denial, and one read/zero drafts for the simulated route-index
outage. Real telemetry, capacity optimisation and vehicle dispatch belong to the
consumer.
