# Zig drone fleet plan (TL-01)

A bounded first slice of TL-01, not an airspace or flight-control system. It
reads fixed drone waypoint state, drafts a review-only waypoint plan and flags a
conflict zone for application-owned review. No flight, avoidance or geofence
command.

Build and run from the repository root:

```bash
zig build-exe --dep praxo -Mroot=language/zig/Tutorial/drone-fleet-plan/main.zig -Mpraxo=language/zig/src/praxo.zig -femit-bin=build/praxo-zig-drone-fleet
./build/praxo-zig-drone-fleet --test
./build/praxo-zig-drone-fleet --drone drone-200
./build/praxo-zig-drone-fleet --simulate-failure
```

Expected test output:

```text
success: drone-100 battery_pct=72 waypoints=3 status=draft_only conflict_review=true commands=0 reads=1
deny: PolicyError reads=0
failure: FleetUnavailable reads=1
```

`drone-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, reports `FleetUnavailable`, and exits `1`.

`read_fleet` returns fixed `drone-100` state (`battery_pct=72`, 3 waypoints,
conflict zone `Z-3`); `draft_flight_plan` returns a 3-waypoint plan with
`conflict_review=true`, `status=draft_only`, `review_required=true` and
`flight_commands=0`. Policy limits the drone and final `draft_waypoints` action.

## Local verification note

On Windows, an emitted Zig binary was quarantined by the local security product,
so local checks used `zig run` with the same module flags. CI builds with
`zig build-exe`. This is an environment workaround, not a tutorial requirement.

Real trajectory validation, airspace conflict resolution, geofencing and flight
dispatch belong to the consumer.
