# Checkpoint Allowlist

This example uses the Lua Core checkpoint allowlist to encode and decode only
registered payload types.

```bash
lua language/lua/examples/checkpoint/checkpoint.lua
```

Expected output:

```text
Lua checkpoint example passed
```

The example covers a registered round trip and rejection of an unregistered
type with `CHECKPOINT_TYPE_NOT_ALLOWED`.
