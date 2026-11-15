# Session Checkpoint

This example saves a session checkpoint in memory, restores it between agent
turns, and continues the conversation. The deterministic model returns
`turn <request message count>`.

From the repository root:

```bash
v -path "language/v|@vlib|@vmodules" language/v/examples/session-checkpoint/starter.v
```

Expected output:

```text
restored messages: 4
output: turn 5
```

Run the deterministic check:

```bash
v -path "language/v|@vlib|@vmodules" test language/v/examples/session-checkpoint
```

The checkpoint payload is encoded with the Core checkpoint allowlist and message
wire helpers, so the store only sees allowlisted session data.
