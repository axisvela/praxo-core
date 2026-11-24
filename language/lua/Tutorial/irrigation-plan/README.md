# Lua irrigation plan (IN-06)

A bounded first slice of IN-06, not an irrigation controller. It evaluates fixed
soil/weather observations and drafts a review-only bounded irrigation request. No
valve command, drone dispatch or actuator access.

## Why this language and runtime?

- **Selection basis:** An existing Lua-enabled host could expose scoped observations
  as tools. Host embedding is a possible use, not demonstrated by this CLI.
- **Demonstrated fit:** Lua callbacks and policy checks return fixed observations,
  a precomputed threshold status and a fixed 400-litre draft request.
- **Choose when:** Learning the Core seam before integrating an existing Lua host.
- **Do not choose when:** Choosing an irrigation controller or expecting hardware
  integration. Compare direct host rules or its existing C control path first.
- **Evidence limit:** Core integration only; no embedded host, live sensor,
  actuator, memory-footprint or real-time guarantee is exercised.

From this directory:

```bash
lua app.lua --test
lua app.lua
lua app.lua field-200
lua app.lua field-100 --simulate-failure
```

Expected test output: `Lua irrigation-plan tutorial: all checks passed`.
The deny and failure commands exit nonzero.

`read_field` returns `field-100` soil moisture 22 against a 30 threshold with
2 mm rain forecast and `status=below_threshold`; `draft_request` returns a
400-litre request with `status=draft_only`, `review=review_required`,
`valve_commands=0` and `drone_commands=0`. Policy limits the field and final
`draft_irrigation` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-field denial, and one read/zero drafts for the simulated field-store
outage. Real soil sensors, irrigation control and agronomy belong to the
producer.
