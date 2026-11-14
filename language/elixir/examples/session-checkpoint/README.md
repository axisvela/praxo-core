# Elixir Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns
using the Core checkpoint allowlist.

```bash
elixir -pa language/elixir/build/ebin language/elixir/examples/session-checkpoint/session_checkpoint.exs
```

Expected output:

```text
restored messages: 4
output: turn 5
```
