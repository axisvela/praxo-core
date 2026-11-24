# Nim Leak Localization (CT-02)

Ranks fixed pressure anomalies and drafts a review-only inspection. No valve
isolation or field dispatch.

## Why this language and runtime?

- **Selection basis:** A Nim utility can sit near utility telemetry and keep the
  review step local.
- **Demonstrated fit:** Native callbacks rank two fixed anomalies and draft one
  inspection request.
- **Choose when:** Evaluating a bounded inspection draft beside existing pressure
  analysis.
- **Do not choose when:** Seeking automatic isolation, dispatch or leak proof.
  Compare hydraulic analysis and field procedures first.
- **Evidence limit:** Fixed pressure series only; no hydraulic model, SCADA,
  valve operation or dispatch. Local validation used `nim check` only; CI is
  configured and pending.

## Build and run

```bash
nim check --path:language/nim/src --hints:off language/nim/Tutorial/leak-localization/leak.nim
nim c --path:language/nim/src --hints:off --out:build/nim-leak-localization language/nim/Tutorial/leak-localization/leak.nim
./build/nim-leak-localization --test
./build/nim-leak-localization
./build/nim-leak-localization --zone zone-200
./build/nim-leak-localization --simulate-failure
```

Expected test output:

```text
success: zone-100 anomalies=2 top=valve-12 status=draft_only isolations=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: PRESSURE_DATA_UNAVAILABLE reads=1
```

No SCADA write, valve isolation or dispatch is implemented. Network ownership,
approval and field verification belong to the consumer.
