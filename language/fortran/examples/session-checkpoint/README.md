# Fortran Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns.
It uses the Core allowlist for payload encoding and a teaching in-memory payload.

Build the pinned RE2 bridge once with
`python language/fortran/run-tests.py --re2-only`, then run:

```bash
python language/fortran/examples/session-checkpoint/run.py
```

Expected output:

```text
restored messages: 4
output: turn 5
```

A checkpoint is a recovery hint, not a transaction or an exactly-once guarantee.
