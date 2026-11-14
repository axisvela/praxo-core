# Checkpoint Allowlist

This example uses the Zig Core checkpoint allowlist for a registered payload
round trip.

```bash
zig build-exe language/zig/examples/checkpoint/checkpoint.zig \
  --dep json --dep runtime \
  -Mroot=language/zig/examples/checkpoint/checkpoint.zig \
  -Mjson=language/zig/src/json.zig -Mruntime=language/zig/src/runtime.zig \
  -femit-bin=build/zig-checkpoint
./build/zig-checkpoint
```

Expected output:

```text
Zig checkpoint example passed
```
