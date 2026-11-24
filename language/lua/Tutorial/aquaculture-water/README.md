# Lua aquaculture water (AE-03)

A bounded first slice of AE-03, not a pond-control system. It computes fixed
oxygen and temperature indicators and drafts a review-only bounded action. No
aerator or feeder commands, actuator access or live model.

## Why this language and runtime?

- **Selection basis:** Aquaculture controllers and gateways often expose Lua scripting,
  so a review step can live where operators already extend the host.
- **Demonstrated fit:** Fixed oxygen/temperature values produce a review-only action;
  no aerator, feeder or sensor bus is accessed.
- **Choose when:** Learning a host-scripting review pattern for pond operations.
- **Do not choose when:** Seeking water-quality control or actuator integration. Compare
  the controller firmware and the farm's operating limits first.
- **Evidence limit:** Core integration fixture only; no sensor, aerator, feeder,
  water-quality validation or production guarantee.

From this directory:

```bash
lua app.lua --test
lua app.lua
lua app.lua pond-200
lua app.lua pond-100 --simulate-failure
```

Expected test output: `Lua aquaculture-water tutorial: all checks passed`.
The deny and failure commands exit nonzero.

`read_water` returns `pond-100` dissolved oxygen 4.2 mg/L against a 5.0 threshold
at 27.5 °C with `status=below_threshold`; `draft_action` returns one action with
`status=draft_only`, `review=review_required`, `aerator_commands=0` and
`feeder_commands=0`. Policy limits the pond and final `draft_action` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-pond denial, and one read/zero drafts for the simulated pond-store outage.
Real sensors, aeration, feeding control and water-quality science belong to the
producer.
