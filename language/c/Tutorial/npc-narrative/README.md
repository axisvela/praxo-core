# C NPC Narrative (PE-05)

Reads fixed character state and drafts one scoped host action with an observed
result. No arbitrary host commands.

## Why this language and runtime?

- **Selection basis:** A C game runtime can call Core in-process without a
  separate narrative service.
- **Demonstrated fit:** Fixed character state yields a draft-only `open_dialogue`
  action and zero host commands.
- **Choose when:** Evaluating a constrained NPC seam in an existing host.
- **Do not choose when:** Seeking shell access or unrestricted host calls.
  Compare the engine API and capability boundary first.
- **Evidence limit:** One fixed character only; no engine integration, save state
  or arbitrary host command. Local validation used `gcc -fsyntax-only` only; CI
  is configured and pending.

## Run

```bash
cc -std=c11 -Ilanguage/c/include language/c/Tutorial/npc-narrative/main.c \
  -Llanguage/c/build -lpraxo_core -lm -o build/npc-narrative
./build/npc-narrative --test
```

Expected output:

```text
success: character-100 mood=curious action=open_dialogue status=draft_only reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: CHARACTER_STATE_UNAVAILABLE reads=1
```

No engine integration or unrestricted host command is implemented. Host
capability and persistence belong to the consumer.
