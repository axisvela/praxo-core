# OCaml Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns.
It uses `session`, `run_agent`, `message_wire`, and the Core checkpoint allowlist
with a teaching in-memory store. Production storage and retention remain
application-owned.

From the repository root:

```bash
ocaml -I language/ocaml language/ocaml/examples/session-checkpoint/session_checkpoint.ml
```

Expected output:

```text
restored messages: 4
output: turn 5
```

The source is a deterministic self-check: the fixture model returns
`turn <request message count>`, and the example fails if the second turn is not
`turn 3` or the third turn is not `turn 5`. The second turn runs against the
first checkpoint, then the updated history is saved and reloaded for the third
turn. A checkpoint is a recovery hint, not a transaction or an exactly-once
guarantee.
