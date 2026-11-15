# Session Checkpoint

This example saves a session checkpoint in memory, restores it between agent
turns, and continues the conversation. The deterministic model returns
`turn <request message count>`.

From the repository root:

```bash
zig run --dep praxo \
  "-Mroot=language/zig/examples/session-checkpoint/starter.zig" \
  "-Mpraxo=language/zig/src/praxo.zig"
```

Expected output:

```text
restored messages: 4
output: turn 5
```

Run the deterministic check:

```bash
zig test --dep praxo \
  "-Mroot=language/zig/examples/session-checkpoint/starter_test.zig" \
  "-Mpraxo=language/zig/src/praxo.zig"
```

The checkpoint payload is encoded with the Core checkpoint allowlist and
`messageWire`, so the store only sees allowlisted session data.
