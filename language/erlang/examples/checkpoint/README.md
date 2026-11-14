# Checkpoint Allowlist

This example uses the Erlang Core checkpoint allowlist to encode and decode
only registered payload types.

After `erlc` has populated `language/erlang/build/ebin`:

```bash
escript language/erlang/examples/checkpoint/checkpoint.escript
```

Expected output:

```text
Erlang checkpoint example passed
```

The example covers a registered round trip and rejection of an unregistered
type with `CHECKPOINT_TYPE_NOT_ALLOWED`.
