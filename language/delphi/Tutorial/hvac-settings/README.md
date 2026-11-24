# Delphi HVAC settings (BE-02)

A bounded first slice of BE-02, not a building-management system. It reads a
fixed building environment and drafts a review-only settings plan using the
source Delphi/Free Pascal Core. No BMS command, energy-savings claim or
occupancy surveillance.

## Why this language and runtime?

- **Selection basis:** Existing Delphi/Free Pascal facility software can embed the
  review step without a separate Agent service. No BMS consumer is verified here.
- **Demonstrated fit:** A Pascal host uses Core tools and policy over a fixed
  environment; occupancy, temperatures and settings are scripted values.
- **Choose when:** Learning the Core seam in an existing Delphi application.
- **Do not choose when:** Seeking BMS integration or energy optimization. Compare
  direct building-control APIs and deterministic comfort rules.
- **Evidence limit:** Core integration fixture only; no BMS command, occupancy
  sensing, energy model, savings guarantee or production deployment.

Build and run from `language/delphi` (so `-Fu.` finds the Core units):

```bash
cd language/delphi
fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild Tutorial/hvac-settings/hvac.pas
./build/hvac --test
./build/hvac
./build/hvac --building building-200
./build/hvac --simulate-failure
```

Expected test output:

```text
success: building-100 occupancy=40 status=draft_only bms_commands=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: ENVIRONMENT_UNAVAILABLE reads=1
```

`building-200` is denied by policy before the tool runs. `--simulate-failure`
reads once, reports `ENVIRONMENT_UNAVAILABLE`, and exits nonzero.

`read_environment` returns occupancy 40, 24.5 °C against a 22.0 °C setpoint,
lighting `on` and 3 zones for `building-100`; `draft_settings` returns
`status=draft_only`, `review_required=true`, `bms_commands=0` and
`energy_claims=0`. Policy limits the building and final `draft_settings` action.

Real BMS integration, occupancy sensing, energy modeling and comfort guarantees
belong to the facility operator.
