# Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns.
It uses a teaching in-memory store; production storage and retention remain
application-owned.

```bash
cd language/python/examples/session-checkpoint
python starter.py
```

Expected output:

```text
restored messages: 4
output: turn 5
```

The second turn runs against the first checkpoint, then the updated history is
saved and reloaded for the third turn. A checkpoint is a recovery hint, not a
transaction or an exactly-once guarantee.
