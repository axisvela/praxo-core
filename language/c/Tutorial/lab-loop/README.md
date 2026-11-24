# C Self-Driving Lab Loop (SC-03)

Simulates one fixed parameter/result cycle and drafts review-only next
parameters. No actuator, chemical handling or autonomous experiment.

## Why this language and runtime?

- **Selection basis:** A C component can sit beside instrument control with
  explicit allocation and caller-owned buffers.
- **Demonstrated fit:** A fixed cycle yields temperature 25, yield 0.72 and a
  draft-only parameter update with zero actuator commands.
- **Choose when:** Evaluating a deterministic lab-loop seam under fixed limits.
- **Do not choose when:** Seeking instrument control or autonomous chemistry.
  Compare the lab safety system and device SDK first.
- **Evidence limit:** One fixed cycle only; no instrument, actuator, chemical
  handling or experimental result. Local validation used `gcc -fsyntax-only`
  only; CI is configured and pending.

## Run

```bash
cmake -S language/c -B language/c/build
cmake --build language/c/build
cc -std=c11 -Ilanguage/c/include language/c/Tutorial/lab-loop/main.c \
  -Llanguage/c/build -lpraxo_core -lm -o build/lab-loop
./build/lab-loop --test
```

Expected output:

```text
success: lab-100 yield=0.72 status=draft_only actuators=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: LAB_DATA_UNAVAILABLE reads=1
```

No instrument, actuator or autonomous experiment is implemented. Safety limits
and execution belong to the consumer.
