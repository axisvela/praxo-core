# Nim Irrigation Plan (IN-06)

Reads fixed soil and weather observations and drafts a bounded irrigation request.
No valve, drone or actuator operation.

## Why this language and runtime?

- **Selection basis:** A small Nim utility can run beside field gateways and embed
  Core through its C backend.
- **Demonstrated fit:** Native callbacks evaluate one field fixture and draft a
  review-only irrigation request.
- **Choose when:** Evaluating the Core seam in an existing Nim field tool.
- **Do not choose when:** Seeking automatic irrigation or actuator control.
  Compare direct threshold rules and the existing agronomy process first.
- **Evidence limit:** Fixed observations only; no sensor feed, weather service,
  actuator, drone or yield claim. Local validation used `nim check` only; CI is
  configured and pending.

## Build and run

```bash
nim check --path:language/nim/src --hints:off language/nim/Tutorial/irrigation-plan/irrigation.nim
nim c --path:language/nim/src --hints:off --out:build/nim-irrigation-plan language/nim/Tutorial/irrigation-plan/irrigation.nim
./build/nim-irrigation-plan --test
./build/nim-irrigation-plan
./build/nim-irrigation-plan --field field-200
./build/nim-irrigation-plan --simulate-failure
```

Expected test output:

```text
success: field-100 moisture=18 status=draft_only actuators=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: SOIL_DATA_UNAVAILABLE reads=1
```

No sensor transport, actuator, irrigation schedule or water-rights decision is
implemented. Field identity, consent and effect reconciliation belong to the
consumer.
