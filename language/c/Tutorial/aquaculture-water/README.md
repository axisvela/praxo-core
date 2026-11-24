# C Aquaculture Water (AE-03)

Computes fixed oxygen/temperature indicators and drafts a bounded review action.
No aerator or feeder command.

## Why this language and runtime?

- **Selection basis:** A C component can run beside pond controllers with
  explicit buffers and no garbage collector.
- **Demonstrated fit:** Oxygen 4.1 mg/L against a 5.0 threshold yields a
  draft-only aeration review with zero actuator commands.
- **Choose when:** Evaluating a bounded water-quality review seam.
- **Do not choose when:** Seeking aerator/feeder control or survival guarantees.
  Compare pond operations and equipment interlocks first.
- **Evidence limit:** One fixed pond only; no probe feed, actuator, survival
  model or water-quality guarantee. Local validation used `gcc -fsyntax-only`
  only; CI is configured and pending.

## Run

```bash
cc -std=c11 -Ilanguage/c/include language/c/Tutorial/aquaculture-water/main.c \
  -Llanguage/c/build -lpraxo_core -lm -o build/aquaculture-water
./build/aquaculture-water --test
```

Expected output:

```text
success: pond-100 oxygen=4.1 status=draft_only aerators=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: WATER_DATA_UNAVAILABLE reads=1
```

No aerator, feeder or probe integration is implemented. Operator approval and
equipment interlocks belong to the consumer.
