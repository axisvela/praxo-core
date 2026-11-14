# Swift Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns.
It uses the Core allowlist for payload encoding and a teaching in-memory payload.

```bash
swift run --package-path language/swift praxo-session-checkpoint-example
```

Expected output:

```text
restored messages: 4
output: turn 5
```

A checkpoint is a recovery hint, not a transaction or an exactly-once guarantee.
