# Julia HVAC Settings (BE-02)

Simulate fixed occupancy and thermal constraints. No production write or external system access.

## Why this language and runtime?

- **Selection basis:** Julia fits deterministic numerical review seams beside
  existing analysis code.
- **Demonstrated fit:** A fixed fixture yields a draft-only result with zero
  writes.
- **Choose when:** Evaluating a bounded review seam in existing Julia numerics.
- **Do not choose when:** Seeking production effects or validated numerical
  guarantees. Compare the existing model and review policy first.
- **Evidence limit:** One fixed fixture only; no live data, solver validation or
  production effect. Local validation ran the fixture test; CI is configured and
  pending.

## Run

```bash
julia --project=language/julia language/julia/Tutorial/hvac-settings/hvac_settings.jl --test
```

Expected output:

```text
success: building-100 occupancy=40 status=draft_only bms=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: BUILDING_DATA_UNAVAILABLE reads=1
```

No production write or external system access is implemented. Approval and effect
reconciliation belong to the consumer.
