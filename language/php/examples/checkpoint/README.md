# Checkpoint Allowlist

This example uses the PHP Core checkpoint allowlist to encode and decode only
registered payload types.

```bash
php language/php/examples/checkpoint/checkpoint.php
```

Expected output:

```text
PHP checkpoint example passed
```

The example covers a registered round trip and rejection of an unregistered
type with `CHECKPOINT_TYPE_NOT_ALLOWED`.
