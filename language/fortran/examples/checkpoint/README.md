# Checkpoint Allowlist

This example uses the Fortran Core checkpoint allowlist to encode and decode
only registered payload types.

```bash
python language/fortran/examples/checkpoint/run.py
```

Expected output:

```text
Fortran checkpoint example passed
```

The example covers a registered round trip and rejection of an unregistered
type with `CHECKPOINT_TYPE_NOT_ALLOWED`.
