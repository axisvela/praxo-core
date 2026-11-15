# Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns.
It uses a teaching in-memory store keyed by session id; production storage and
retention remain application-owned.

```bash
octave-cli --path language/matlab-octave-core \
  --path language/matlab/examples/session-checkpoint \
  --eval session_checkpoint_example
```

Expected output:

```text
restored messages: 4
output: turn 5
```

Set `options.messages` to prior messages before `praxo.agent_run`; the result
includes the full updated history in `result.messages`. The second turn runs
against the first checkpoint, then the updated history is saved and reloaded for
the third turn. A checkpoint is a recovery hint, not a transaction or an
exactly-once guarantee.
