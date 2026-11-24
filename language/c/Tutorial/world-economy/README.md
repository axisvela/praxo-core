# C World Economy (MD-03)

Simulates one fixed economy tick and drafts a review-only balance action. No
long-term equilibrium or scale guarantee.

## Why this language and runtime?

- **Selection basis:** A C simulation loop can keep Core beside fixed-tick game
  simulation code.
- **Demonstrated fit:** One tick yields supply 100, demand 115, price 12.5 and a
  draft-only price-adjustment review.
- **Choose when:** Evaluating a bounded economy-review seam.
- **Do not choose when:** Seeking equilibrium, scale or live economy changes.
  Compare the simulation design first.
- **Evidence limit:** One fixed tick only; no player data, scale test, long-term
  equilibrium or economy write. Local validation used `gcc -fsyntax-only` only;
  CI is configured and pending.

## Run

```bash
cc -std=c11 -Ilanguage/c/include language/c/Tutorial/world-economy/main.c \
  -Llanguage/c/build -lpraxo_core -lm -o build/world-economy
./build/world-economy --test
```

Expected output:

```text
success: world-100 demand=115 status=draft_only writes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: ECONOMY_TICK_UNAVAILABLE reads=1
```

No long-term simulation, player data or economy write is implemented. Balance
approval belongs to the consumer.
