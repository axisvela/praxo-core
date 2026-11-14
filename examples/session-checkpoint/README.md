# Multi-turn Checkpoint Recovery

This example shows a two-step multi-turn flow:

1. start with two messages from a saved checkpoint;
2. run the agent for a second turn;
3. save the updated history and reload it;
4. run a third turn and verify the history survived recovery.

```bash
GOWORK=off go run ./examples/session-checkpoint
```

Expected output:

```text
restored messages: 4
output: turn 5
```

The store is a teaching in-memory map. Production applications must provide
durable storage, tenant scoping, retention, and recovery policy. A checkpoint is
a recovery hint, not a transaction or an exactly-once guarantee.
