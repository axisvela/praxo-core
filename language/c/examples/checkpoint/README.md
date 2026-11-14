# Checkpoint Allowlist

This example uses the C Core checkpoint allowlist to encode and decode only
registered payload types.

```bash
gcc -std=c11 -I language/c/include language/c/examples/checkpoint/main.c \
  language/c/build/libpraxo_core.a -o build/c-checkpoint
./build/c-checkpoint
```

Expected output:

```text
C checkpoint example passed
```

The example covers a registered round trip and rejection of an unregistered
type with `CHECKPOINT_TYPE_NOT_ALLOWED`.
