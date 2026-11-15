# Nim Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns.
It uses the Nim Core `Session`, `runAgent`, and `messageWire` APIs with the
checkpoint allowlist for payload encoding and a teaching in-memory store keyed by
session id.

```bash
nim r --path:language/nim/src \
  language/nim/examples/session-checkpoint/session_checkpoint.nim
```

Expected output:

```text
restored messages: 4
output: turn 5
```

Run the deterministic self-check with:

```bash
nim r --path:language/nim/src \
  language/nim/examples/session-checkpoint/test_session_checkpoint.nim
```

Expected output:

```text
Nim session checkpoint test passed
```

The second turn runs against the first checkpoint, then the updated history is
saved and reloaded for the third turn. A checkpoint is a recovery hint, not a
transaction or an exactly-once guarantee.
