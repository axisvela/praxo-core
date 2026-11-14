# R Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns
using the Core checkpoint allowlist.

```bash
cd language/r/examples/session-checkpoint
Rscript starter.R
```

Expected output:

```text
restored messages: 4
output: turn 5
```

A checkpoint is a recovery hint, not a transaction or an exactly-once guarantee.
