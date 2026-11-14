# Checkpoint Allowlist

This example uses the Ruby Core checkpoint allowlist to encode and decode only
registered payload types.

```bash
ruby -I language/ruby/lib language/ruby/examples/checkpoint/checkpoint.rb
```

Expected output:

```text
Ruby checkpoint example passed
```

The example covers a registered round trip and rejection of an unregistered
type with `CHECKPOINT_TYPE_NOT_ALLOWED`.
