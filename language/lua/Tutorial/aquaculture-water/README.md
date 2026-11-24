# Lua aquaculture water (AE-03)

A bounded first slice of AE-03, not a pond-control system. It computes fixed
oxygen and temperature indicators and drafts a review-only bounded action. No
aerator or feeder commands, actuator access or live model.

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
