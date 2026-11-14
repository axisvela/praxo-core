# Checkpoint Allowlist

This example uses the COBOL Core checkpoint allowlist to encode and decode only
registered payload types.

```bash
python language/cobol/examples/checkpoint/build.py
```

Expected output:

```text
COBOL checkpoint example passed
```

The example covers a registered round trip and rejection of an unregistered
type with `CHECKPOINT_TYPE_NOT_ALLOWED`.
