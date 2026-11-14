# Checkpoint Allowlist

This example uses the R Core checkpoint allowlist to encode and decode only
registered payload types.

```bash
Rscript language/r/examples/checkpoint/checkpoint.R
```

Expected output:

```text
R checkpoint example passed
```

The example covers a registered round trip and rejection of an unregistered
type with `CHECKPOINT_TYPE_NOT_ALLOWED`.
