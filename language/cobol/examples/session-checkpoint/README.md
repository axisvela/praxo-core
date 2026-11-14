# COBOL Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns.
It uses the Core allowlist for payload encoding and a teaching in-memory payload.

```bash
python language/cobol/examples/session-checkpoint/build.py
```

Expected output:

```text
restored messages: 4
output: turn 5
```

The payload stores the restored message count and the last assistant output. A
checkpoint is a recovery hint, not a transaction or an exactly-once guarantee.
