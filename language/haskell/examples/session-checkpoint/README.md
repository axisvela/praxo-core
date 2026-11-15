# Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns
with the Haskell Core `runAgent` loop and checkpoint allowlist helpers. It uses a
teaching in-memory store; production storage and retention remain
application-owned.

```bash
runghc -ilanguage/haskell/src language/haskell/examples/session-checkpoint/session_checkpoint.hs
```

Expected output:

```text
restored messages: 4
output: turn 5
```

The second turn runs against the first checkpoint, then the updated history is
saved and reloaded for the third turn. A checkpoint is a recovery hint, not a
transaction or an exactly-once guarantee.
