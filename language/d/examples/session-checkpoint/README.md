# D Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns.
It uses the Core allowlist for payload encoding and a teaching in-memory payload.

```bash
cd language/d
mkdir -p build
dmd -i -Isource -O -release examples/session-checkpoint/session_checkpoint.d -of=build/session-checkpoint
./build/session-checkpoint
```

Expected output:

```text
restored messages: 4
output: turn 5
```

A checkpoint is a recovery hint, not a transaction or an exactly-once guarantee.
