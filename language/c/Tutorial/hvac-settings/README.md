# C HVAC Settings (BE-02)

Reads fixed building conditions and drafts review-only HVAC/lighting settings.
No BMS command or verified energy savings.

## Why this language and runtime?

- **Selection basis:** A C component can run beside building controllers with
  explicit memory and transport constraints.
- **Demonstrated fit:** Fixed occupancy and thermal data yield a draft-only
  setpoint plan with zero BMS commands.
- **Choose when:** Evaluating a settings-review seam before BMS integration.
- **Do not choose when:** Seeking direct BMS control or savings guarantees.
  Compare the building automation system and commissioning first.
- **Evidence limit:** One fixed building only; no BMS, sensor feed, energy model
  or savings claim. Local validation used `gcc -fsyntax-only` only; CI is
  configured and pending.

## Run

```bash
cc -std=c11 -Ilanguage/c/include language/c/Tutorial/hvac-settings/main.c \
  -Llanguage/c/build -lpraxo_core -lm -o build/hvac-settings
./build/hvac-settings --test
```

Expected output:

```text
success: building-100 occupancy=40 status=draft_only bms_commands=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: BUILDING_DATA_UNAVAILABLE reads=1
```

No BMS command, sensor feed or energy-savings claim is implemented. Approval and
commissioning belong to the consumer.
